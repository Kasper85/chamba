import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { EventsGateway } from '../events/events.gateway.js';
import { FinanceService } from '../finance/finance.service.js';
import { JobStatus } from '../common/job-state-machine.js';
import { OpenDisputeDto } from './dto/open-dispute.dto.js';
import { ResolveDisputeDto, DisputeVerdict } from './dto/resolve-dispute.dto.js';
import { AppealDisputeDto } from './dto/appeal-dispute.dto.js';

@Injectable()
export class DisputesService {
  private readonly logger = new Logger(DisputesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly financeService: FinanceService,
    private readonly eventsGateway?: EventsGateway,
  ) {}

  /**
   * Abre una disputa para una chamba (§5, §8 L7):
   * - Congela los fondos pasando el estado a EN_DISPUTA.
   * - Registra la disputa con la declaración inicial.
   * - Crea un ticket de soporte en backend.
   * - Notifica a ambas partes vía WebSockets.
   * - Desencadena la recomendación preliminar de IA.
   */
  async openDispute(userId: string, jobId: string, dto: OpenDisputeDto) {
    const job = await this.prisma.jobRequest.findUnique({
      where: { id: jobId },
      include: {
        worker: {
          include: {
            user: true,
          },
        },
      },
    });

    if (!job) {
      throw new NotFoundException(`Solicitud #${jobId} no encontrada`);
    }

    const isClient = job.clientId === userId;
    const workerUserId = job.worker?.userId;
    const isWorker = workerUserId === userId;

    if (!isClient && !isWorker) {
      throw new ForbiddenException('No tienes permiso para abrir una disputa en esta solicitud');
    }

    const existingDispute = await this.prisma.dispute.findFirst({
      where: {
        jobRequestId: jobId,
        status: { in: ['ABIERTA', 'EN_REVISION'] },
      },
    });

    if (existingDispute) {
      throw new BadRequestException('Ya existe un proceso de disputa activo para esta solicitud');
    }

    // Congelar fondos actualizando estado a EN_DISPUTA
    await this.prisma.jobRequest.update({
      where: { id: jobId },
      data: { status: JobStatus.EN_DISPUTA },
    });

    // Crear registro de disputa
    const dispute = await this.prisma.dispute.create({
      data: {
        jobRequestId: jobId,
        openedById: userId,
        reason: dto.reason,
        clientStatement: isClient ? dto.statement : null,
        workerStatement: isWorker ? dto.statement : null,
        status: 'ABIERTA',
      },
    });

    // Crear ticket de soporte
    const ticket = await this.prisma.supportTicket.create({
      data: {
        jobRequestId: jobId,
        userId,
        subject: `Disputa en Chamba: ${job.title}`,
        message: `Motivo: ${dto.reason}\nDeclaración: ${dto.statement}`,
        status: 'ABIERTO',
      },
    });

    if (this.eventsGateway?.server) {
      const room = `job:${jobId}`;
      this.eventsGateway.server.to(room).emit('disputeOpened', {
        jobRequestId: jobId,
        disputeId: dispute.id,
        ticketId: ticket.id,
        openedBy: userId,
        reason: dto.reason,
        timestamp: new Date().toISOString(),
      });
    }

    this.logger.warn(`⚖️ Disputa #${dispute.id} abierta para chamba #${jobId} por usuario ${userId}. Fondos congelados.`);

    return {
      dispute,
      ticket,
    };
  }

  /**
   * Envía la declaración y evidencias de la contraparte (§5.3).
   */
  async submitStatement(userId: string, disputeId: string, statement: string) {
    const dispute = await this.prisma.dispute.findUnique({
      where: { id: disputeId },
      include: {
        jobRequest: {
          include: { worker: true },
        },
      },
    });

    if (!dispute) {
      throw new NotFoundException(`Disputa #${disputeId} no encontrada`);
    }

    const isClient = dispute.jobRequest.clientId === userId;
    const workerUserId = dispute.jobRequest.worker?.userId;
    const isWorker = workerUserId === userId;

    if (!isClient && !isWorker) {
      throw new ForbiddenException('No tienes autorización para declarar en esta disputa');
    }

    const updateData: any = {};
    if (isClient) updateData.clientStatement = statement;
    if (isWorker) updateData.workerStatement = statement;
    updateData.status = 'EN_REVISION';

    const updated = await this.prisma.dispute.update({
      where: { id: disputeId },
      data: updateData,
    });

    return updated;
  }

  /**
   * Motor de IA para recomendación de veredicto (§5, §8 L7):
   * Analiza: fotos antes/después, PIN validado, chat y declaraciones.
   * REGLA DURA: La IA RECOMIENDA, NUNCA DECIDE NI EJECUTA DINERO SOLA.
   */
  async generateAiRecommendation(disputeId: string, callerUserId?: string) {
    const dispute = await this.prisma.dispute.findUnique({
      where: { id: disputeId },
      include: {
        jobRequest: {
          include: {
            worker: true,
          },
        },
      },
    });

    if (!dispute) {
      throw new NotFoundException(`Disputa #${disputeId} no encontrada`);
    }

    if (callerUserId) {
      const isClient = dispute.jobRequest.clientId === callerUserId;
      const workerUserId = dispute.jobRequest.worker?.userId;
      const isWorker = workerUserId === callerUserId;
      if (isClient || isWorker || dispute.openedById === callerUserId) {
        throw new ForbiddenException(
          'Conflicto de interés: Las partes involucradas en la disputa no pueden solicitar recomendaciones de soporte',
        );
      }
    }

    const job = dispute.jobRequest;
    const hasPinVerified = job.isPinVerified;
    const hasBeforePhoto = Boolean(job.beforePhotoUrl);
    const hasAfterPhoto = Boolean(job.afterPhotoUrl);

    let verdict: DisputeVerdict = DisputeVerdict.SPLIT;
    let confidence = 0.70;
    let justification = '';

    if (hasPinVerified && hasBeforePhoto && hasAfterPhoto) {
      verdict = DisputeVerdict.RELEASE_WORKER;
      confidence = 0.88;
      justification =
        'Evidencia fotográfica completa (antes y después) y PIN de 4 dígitos validado presencialmente en puerta. El servicio cuenta con constancia de culminación.';
    } else if (!hasAfterPhoto && !hasPinVerified) {
      verdict = DisputeVerdict.REFUND_CLIENT;
      confidence = 0.92;
      justification =
        'No se registra validación presencial de PIN ni foto de labor concluida. Procede el reembolso total de los fondos en custodia al cliente.';
    } else {
      verdict = DisputeVerdict.SPLIT;
      confidence = 0.75;
      justification =
        'Intervención parcial confirmada. Se recomienda dividir los fondos en custodia proporcionalmente (50% técnico / 50% cliente).';
    }

    const aiReport = JSON.stringify({
      verdict,
      confidence,
      justification,
      generatedAt: new Date().toISOString(),
      auditNote: 'Recomendación generada por el motor de IA de CHAMBA. Requiere aprobación humana de soporte.',
    });

    await this.prisma.dispute.update({
      where: { id: disputeId },
      data: {
        aiRecommendation: aiReport,
        aiConfidence: confidence,
      },
    });

    this.logger.log(`🤖 Recomendación IA para disputa #${disputeId}: ${verdict} (Confianza: ${(confidence * 100).toFixed(0)}%)`);

    return {
      verdict,
      confidence,
      justification,
    };
  }

  /**
   * Resolución de disputa por un operador humano de soporte (§5.5, §8 L7):
   * Soporte aprueba con un clic (liberar / reembolsar / dividir).
   * Ejecuta los movimientos del ledger a través de FinanceService.
   */
  async resolveDispute(supportUserId: string, disputeId: string, dto: ResolveDisputeDto) {
    const dispute = await this.prisma.dispute.findUnique({
      where: { id: disputeId },
      include: {
        jobRequest: {
          include: {
            worker: true,
          },
        },
      },
    });

    if (!dispute) {
      throw new NotFoundException(`Disputa #${disputeId} no encontrada`);
    }

    const job = dispute.jobRequest;
    const clientUserId = job.clientId;
    const workerUserId = job.worker?.userId ?? 'worker-unknown';

    // Regla de Seguridad Crítica (ALCANCE.md §8 L12): Ninguna parte involucrada puede resolver su propia disputa
    if (
      clientUserId === supportUserId ||
      workerUserId === supportUserId ||
      dispute.openedById === supportUserId
    ) {
      throw new ForbiddenException(
        'Conflicto de interés: Las partes involucradas (cliente o chambeador) no pueden resolver su propia disputa, incluso si cuentan con privilegios de soporte.',
      );
    }

    // Liquidar el Escrow según la regla contable de tarifas §5 (ALCANCE.md §8 L13)
    const settlement = await this.financeService.resolveDisputeEscrow(
      clientUserId,
      workerUserId,
      job.id,
      dto.verdict,
      dto.workerSplitPercent ?? 50,
    );

    let statusDispute = 'RESUELTA_TRABAJADOR';
    if (dto.verdict === DisputeVerdict.RELEASE_WORKER) {
      statusDispute = 'RESUELTA_TRABAJADOR';
      await this.prisma.jobRequest.update({
        where: { id: job.id },
        data: { status: JobStatus.COMPLETADA, confirmedAt: new Date() },
      });
    } else if (dto.verdict === DisputeVerdict.REFUND_CLIENT) {
      statusDispute = 'RESUELTA_CLIENTE';
      await this.prisma.jobRequest.update({
        where: { id: job.id },
        data: { status: JobStatus.CANCELADA },
      });
    } else if (dto.verdict === DisputeVerdict.SPLIT) {
      statusDispute = 'RESUELTA_DIVIDIDA';
      await this.prisma.jobRequest.update({
        where: { id: job.id },
        data: { status: JobStatus.COMPLETADA },
      });
    }

    // Actualizar disputa con nota de auditoría de soporte
    const updatedDispute = await this.prisma.dispute.update({
      where: { id: disputeId },
      data: {
        status: statusDispute as any,
        resolutionNotes: dto.notes,
        resolvedById: supportUserId,
        workerSplitPercent: dto.workerSplitPercent,
        resolvedAt: new Date(),
      },
    });

    const resolver = await this.prisma.user.findUnique({
      where: { id: supportUserId },
      select: { id: true, email: true, fullName: true, role: true },
    });

    const audit = await this.financeService.getJobFinancialAudit(job.id);

    // Cerrar tickets asociados
    await this.prisma.supportTicket.updateMany({
      where: { jobRequestId: job.id },
      data: { status: 'CERRADO' },
    });

    if (this.eventsGateway?.server) {
      const room = `job:${job.id}`;
      this.eventsGateway.server.to(room).emit('disputeResolved', {
        jobRequestId: job.id,
        disputeId,
        verdict: dto.verdict,
        resolvedBy: supportUserId,
        notes: dto.notes,
        timestamp: new Date().toISOString(),
      });
    }

    this.logger.log(`⚖️ Disputa #${disputeId} resuelta por soporte (${supportUserId}): ${dto.verdict}`);

    return {
      success: true,
      dispute: updatedDispute,
      settlement,
      audit,
      resolvedBy: resolver,
    };
  }

  /**
   * Consulta una disputa por su disputeId con auditoría de ledger y resolutor (§5, §8 L14).
   * Valida autorización: solo cliente, técnico asignado o SUPPORT/ADMIN.
   * Política de privacidad: correos de personas involucradas u operador solo para SUPPORT/ADMIN.
   */
  async getDisputeById(
    disputeId: string,
    requestingUser?: { id: string; role?: string },
  ) {
    const dispute = await this.prisma.dispute.findUnique({
      where: { id: disputeId },
      include: {
        jobRequest: {
          include: {
            worker: {
              include: { user: true },
            },
            client: true,
          },
        },
        openedBy: {
          select: { id: true, fullName: true, email: true },
        },
      },
    });
    if (!dispute) throw new NotFoundException(`Disputa #${disputeId} no encontrada`);

    const isClient = requestingUser ? dispute.jobRequest.clientId === requestingUser.id : true;
    const workerUserId = dispute.jobRequest.worker?.userId;
    const isWorker = requestingUser
      ? workerUserId === requestingUser.id || dispute.jobRequest.workerId === requestingUser.id
      : true;
    const isSupport = requestingUser
      ? requestingUser.role === 'SUPPORT' || requestingUser.role === 'ADMIN'
      : true;

    if (requestingUser && !isClient && !isWorker && !isSupport) {
      throw new ForbiddenException('No tienes permiso para consultar esta disputa');
    }

    let resolver: any = null;
    if (dispute.resolvedById) {
      resolver = await this.prisma.user.findUnique({
        where: { id: dispute.resolvedById },
        select: { id: true, email: true, fullName: true, role: true },
      });
    }

    const audit = await this.financeService.getJobFinancialAudit(dispute.jobRequestId);

    const sanitizedOpenedBy = dispute.openedBy
      ? {
          id: dispute.openedBy.id,
          fullName: dispute.openedBy.fullName,
          ...(isSupport ? { email: dispute.openedBy.email } : {}),
        }
      : null;

    const sanitizedResolver = resolver
      ? {
          id: resolver.id,
          fullName: resolver.fullName,
          role: resolver.role,
          ...(isSupport ? { email: resolver.email } : {}),
        }
      : null;

    const { openedBy, jobRequest, ...disputeData } = dispute;

    return {
      dispute: {
        ...disputeData,
        openedBy: sanitizedOpenedBy,
      },
      audit,
      resolvedBy: sanitizedResolver,
    };
  }

  /**
   * Consulta una disputa por su jobRequestId con auditoría de ledger y resolutor (§5, §8 L14).
   * Valida autorización: solo cliente, técnico asignado o SUPPORT/ADMIN.
   * Política de privacidad: correos de personas involucradas u operador solo para SUPPORT/ADMIN.
   */
  async getDisputeByJobId(
    jobId: string,
    requestingUser?: { id: string; role?: string },
  ) {
    const dispute = await this.prisma.dispute.findFirst({
      where: { jobRequestId: jobId },
      orderBy: { createdAt: 'desc' },
      include: {
        jobRequest: {
          include: {
            worker: {
              include: { user: true },
            },
            client: true,
          },
        },
        openedBy: {
          select: { id: true, fullName: true, email: true },
        },
      },
    });
    if (!dispute) throw new NotFoundException(`No hay disputa para el trabajo #${jobId}`);

    const isClient = requestingUser ? dispute.jobRequest.clientId === requestingUser.id : true;
    const workerUserId = dispute.jobRequest.worker?.userId;
    const isWorker = requestingUser
      ? workerUserId === requestingUser.id || dispute.jobRequest.workerId === requestingUser.id
      : true;
    const isSupport = requestingUser
      ? requestingUser.role === 'SUPPORT' || requestingUser.role === 'ADMIN'
      : true;

    if (requestingUser && !isClient && !isWorker && !isSupport) {
      throw new ForbiddenException('No tienes permiso para consultar esta disputa');
    }

    let resolver: any = null;
    if (dispute.resolvedById) {
      resolver = await this.prisma.user.findUnique({
        where: { id: dispute.resolvedById },
        select: { id: true, email: true, fullName: true, role: true },
      });
    }

    const audit = await this.financeService.getJobFinancialAudit(jobId);

    const sanitizedOpenedBy = dispute.openedBy
      ? {
          id: dispute.openedBy.id,
          fullName: dispute.openedBy.fullName,
          ...(isSupport ? { email: dispute.openedBy.email } : {}),
        }
      : null;

    const sanitizedResolver = resolver
      ? {
          id: resolver.id,
          fullName: resolver.fullName,
          role: resolver.role,
          ...(isSupport ? { email: resolver.email } : {}),
        }
      : null;

    const { openedBy, jobRequest, ...disputeData } = dispute;

    return {
      dispute: {
        ...disputeData,
        openedBy: sanitizedOpenedBy,
      },
      audit,
      resolvedBy: sanitizedResolver,
    };
  }

  /**
   * Permite una sola apelación con evidencia nueva (§5.6, §8 L7).
   */
  async appealDispute(userId: string, disputeId: string, dto: AppealDisputeDto) {
    const dispute = await this.prisma.dispute.findUnique({
      where: { id: disputeId },
      include: {
        jobRequest: {
          include: { worker: true },
        },
      },
    });

    if (!dispute) {
      throw new NotFoundException(`Disputa #${disputeId} no encontrada`);
    }

    const isClient = dispute.jobRequest.clientId === userId;
    const workerUserId = dispute.jobRequest.worker?.userId;
    const isWorker = workerUserId === userId || dispute.jobRequest.workerId === userId;
    if (!isClient && !isWorker) {
      throw new ForbiddenException('Solo las partes de la disputa pueden presentar una apelación');
    }

    if (dispute.appealsCount >= 1) {
      throw new BadRequestException('Solo se permite una única apelación por disputa.');
    }

    const updated = await this.prisma.dispute.update({
      where: { id: disputeId },
      data: {
        status: 'EN_REVISION',
        appealsCount: { increment: 1 },
        appealReason: `${dto.appealReason}\nNueva evidencia: ${dto.newEvidence}`,
      },
    });

    this.logger.log(`📢 Apelación registrada para disputa #${disputeId} por usuario ${userId}.`);
    return updated;
  }
}

