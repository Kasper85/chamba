import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { describe, it, expect } from 'vitest';
import { WorkerProfileService } from '../src/worker-profile/worker-profile.service.js';

describe.skipIf(process.env.RUN_WORKER_DB_TESTS !== '1')('Profile roundtrip in PostgreSQL', () => {
  it('reloads professional fields and portfolio from a fresh database query', async () => {
    const prisma = new PrismaClient();
    const rollback = new Error('rollback-test');
    try {
      await prisma.$transaction(async tx => {
        const user = await tx.user.create({ data: { email: `${randomUUID()}@profile-test.invalid`, fullName: 'Prueba transaccional', passwordHash: 'not-a-login' } });
        const service = new WorkerProfileService({ workerProfile: tx.workerProfile, $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as never);
        await service.upsertMyProfile(user.id, { bio: 'Experiencia real', specialty: 'Pintura', skills: ['Pintura', 'Electricidad'], dni: '12345678', baseRate: 80, serviceRadiusKm: 15, experienceYears: 0 });
        const image = 'data:image/jpeg;base64,/9j/2Q==';
        await service.addPortfolio(user.id, { title: 'Mi obra', category: 'Pintura', beforeDescription: 'Antes', afterDescription: 'Después', beforeImageUrl: image, afterImageUrl: image });
        const loaded = await tx.user.findUniqueOrThrow({ where: { id: user.id }, include: { workerProfile: true } });
        expect(loaded.workerProfile).toMatchObject({ dni: '12345678', baseRate: 80, serviceRadiusKm: 15, experienceYears: 0, skills: ['Pintura', 'Electricidad'] });
        expect(loaded.workerProfile!.portfolio).toMatchObject([{ title: 'Mi obra', beforeImageUrl: image, afterImageUrl: image }]);
        throw rollback;
      });
    } catch (error) { if (error !== rollback) throw error; }
    finally { await prisma.$disconnect(); }
  });
});
