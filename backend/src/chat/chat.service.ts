import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, JobStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService) {}

  private async access(tx: Prisma.TransactionClient, jobId: string, userId: string) {
    // Serialize sends with completion/dispute transitions so no message can survive closure.
    await tx.$queryRaw`SELECT id FROM job_requests WHERE id = ${jobId} FOR UPDATE`;
    const job = await tx.jobRequest.findUnique({ where: { id: jobId }, include: { worker: true, disputes: { where: { status: { in: ['ABIERTA', 'EN_REVISION'] } }, select: { id: true } } } });
    if (!job) throw new NotFoundException('Solicitud no encontrada');
    if (job.clientId !== userId && job.worker?.userId !== userId) throw new ForbiddenException('No tienes acceso a esta conversación');
    const closed = [JobStatus.COMPLETADA, JobStatus.CANCELADA, JobStatus.REEMBOLSADA].includes(job.status as never) && !(job.disputes?.length);
    return { job, closed };
  }

  async list(jobId: string, userId: string) {
    return this.prisma.$transaction(async tx => {
      const { job, closed } = await this.access(tx, jobId, userId);
      const messages = closed ? [] : await tx.message.findMany({ where: { jobRequestId: jobId }, orderBy: [{ createdAt: 'asc' }, { id: 'asc' }], include: { sender: { select: { fullName: true } } } });
      return { closed, status: job.status, messages: messages.map(m => ({ ...m, isFromWorker: m.senderId !== job.clientId, senderName: m.sender.fullName, sender: undefined })) };
    });
  }

  async send(jobId: string, userId: string, clientMessageId: string, text: string, audioBase64?: string, audioDurationSeconds?: number) {
    if (audioBase64 !== undefined) {
      const audio = Buffer.from(audioBase64, 'base64');
      if (!audioDurationSeconds || audioDurationSeconds < 1 || audioDurationSeconds > 30 || audio.length < 7 || audio.length > 200000 || audio[0] !== 255 || (audio[1] & 240) !== 240) throw new BadRequestException('Audio inválido. Graba hasta 30 segundos.');
    } else if (audioDurationSeconds !== undefined) throw new BadRequestException('Falta el audio');
    if (!text.trim() || text.length > 4000 || !clientMessageId.trim() || clientMessageId.length > 100) throw new BadRequestException('Mensaje inválido');
    return this.prisma.$transaction(async tx => {
      const { job, closed } = await this.access(tx, jobId, userId);
      if (closed) throw new BadRequestException('El servicio finalizó y el chat está cerrado');
      if (!job.workerId) throw new BadRequestException('El chat se habilita al asignar un trabajador');
      return tx.message.upsert({
        where: { jobRequestId_senderId_clientMessageId: { jobRequestId: jobId, senderId: userId, clientMessageId } },
        create: { jobRequestId: jobId, senderId: userId, clientMessageId, text: text.trim(), audioBase64, audioDurationSeconds }, update: {},
      });
    });
  }

  async delivered(jobId: string, userId: string, messageIds: string[] = []) {
    return this.prisma.$transaction(async tx => {
      const { closed } = await this.access(tx, jobId, userId);
      if (closed) return { count: 0 };
      return tx.message.updateMany({ where: { jobRequestId: jobId, id: { in: messageIds }, senderId: { not: userId }, deliveredAt: null }, data: { deliveredAt: new Date() } });
    });
  }
}
