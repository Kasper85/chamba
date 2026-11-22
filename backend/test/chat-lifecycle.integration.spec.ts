import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { describe, it, expect } from 'vitest';

describe.skipIf(process.env.RUN_CHAT_DB_TESTS !== '1')('Chat deletion in PostgreSQL', () => {
  it('retains disputed messages, purges on resolution and keeps the job receipt data', async () => {
    const prisma = new PrismaClient();
    const rollback = new Error('intentional-test-rollback');
    try {
      await prisma.$transaction(async tx => {
        const user = await tx.user.create({ data: { email: `${randomUUID()}@chat-test.invalid`, fullName: 'Prueba temporal', passwordHash: 'not-a-login' } });
        const job = await tx.jobRequest.create({ data: { clientId: user.id, title: 'Prueba transaccional', description: 'Solo prueba', category: 'Otros', district: 'Prueba', budget: 100, agreedPrice: 95, status: 'EN_DISPUTA' } });
        const dispute = await tx.dispute.create({ data: { jobRequestId: job.id, openedById: user.id, reason: 'Prueba' } });
        await tx.message.create({ data: { clientMessageId: randomUUID(), jobRequestId: job.id, senderId: user.id, text: 'Acuerdo', audioBase64: '//FQgAAAAA==', audioDurationSeconds: 2 } });
        await tx.jobRequest.update({ where: { id: job.id }, data: { status: 'COMPLETADA' } });
        expect(await tx.message.count({ where: { jobRequestId: job.id } })).toBe(1);
        await tx.dispute.update({ where: { id: dispute.id }, data: { status: 'RESUELTA_TRABAJADOR' } });
        expect(await tx.message.count({ where: { jobRequestId: job.id } })).toBe(0);
        expect(await tx.jobRequest.findUnique({ where: { id: job.id } })).toMatchObject({ title: 'Prueba transaccional' });
        const savedJob = await tx.jobRequest.findUniqueOrThrow({ where: { id: job.id } });
        expect(Number(savedJob.agreedPrice)).toBe(95);
        throw rollback;
      });
    } catch (error) {
      if (error !== rollback) throw error;
    } finally {
      await prisma.$disconnect();
    }
  });
  it.each(['COMPLETADA', 'CANCELADA', 'REEMBOLSADA'] as const)('purges immediately when status becomes %s', async status => {
    const prisma = new PrismaClient();
    const rollback = new Error('rollback');
    try {
      await prisma.$transaction(async tx => {
        const user = await tx.user.create({ data: { email: `${randomUUID()}@chat-test.invalid`, fullName: 'Prueba', passwordHash: 'not-a-login' } });
        const job = await tx.jobRequest.create({ data: { clientId: user.id, title: 'Temporal', description: 'Prueba', category: 'Otros', district: 'Prueba', budget: 100 } });
        await tx.message.create({ data: { clientMessageId: randomUUID(), jobRequestId: job.id, senderId: user.id, text: 'Mensaje temporal' } });
        await tx.jobRequest.update({ where: { id: job.id }, data: { status } });
        expect(await tx.message.count({ where: { jobRequestId: job.id } })).toBe(0);
        expect(await tx.jobRequest.count({ where: { id: job.id } })).toBe(1);
        throw rollback;
      });
    } catch (error) {
      if (error !== rollback) throw error;
    } finally { await prisma.$disconnect(); }
  });
});
