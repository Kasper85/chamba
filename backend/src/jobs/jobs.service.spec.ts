import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { JobsService } from './jobs.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { EventsGateway } from '../events/events.gateway.js';
import { FinanceService } from '../finance/finance.service.js';
import { JobStatus } from '../common/job-state-machine.js';

describe('JobsService (Unit Tests)', () => {
  let service: JobsService;

  const mockPrismaService = {
    jobRequest: {
      create: vi.fn(),
      findMany: vi.fn(),
      findUnique: vi.fn(),
      update: vi.fn(),
      count: vi.fn(),
    },
    bid: {
      create: vi.fn(),
      findUnique: vi.fn(),
      update: vi.fn(),
      updateMany: vi.fn(),
    },
    workerProfile: {
      findUnique: vi.fn(),
      update: vi.fn(),
    },
    ledgerEntry: {
      findFirst: vi.fn(),
      create: vi.fn(),
    },
    user: {
      update: vi.fn(),
    },
    rating: {
      create: vi.fn(),
      findMany: vi.fn(),
    },
    $transaction: vi.fn((callback) => callback(mockPrismaService)),
  };

  const mockFinanceService = {
    releaseEscrow: vi.fn(),
    refundEscrow: vi.fn(),
  };

  const mockEventsGateway = {
    server: {
      to: vi.fn().mockReturnThis(),
      emit: vi.fn(),
    },
  };

  beforeEach(async () => {
    vi.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        JobsService,
        {
          provide: PrismaService,
          useValue: mockPrismaService,
        },
        {
          provide: EventsGateway,
          useValue: mockEventsGateway,
        },
        {
          provide: FinanceService,
          useValue: mockFinanceService,
        },
      ],
    }).compile();

    service = module.get<JobsService>(JobsService);
  });

  describe('createJob', () => {
    it('debe crear una chamba en estado BUSCANDO y generar un PIN de seguridad de 4 dígitos', async () => {
      const mockCreated = {
        id: 'job-test-1',
        clientId: 'user-client-1',
        title: 'Fuga de agua',
        description: 'Tubería rota en cocina',
        category: 'gasfiteria',
        budget: 60.0,
        district: 'Chiclayo',
        status: JobStatus.BUSCANDO,
        securityPin: '4821',
        createdAt: new Date(),
      };
      mockPrismaService.jobRequest.create.mockResolvedValue(mockCreated);

      const result = await service.createJob('user-client-1', {
        title: 'Fuga de agua',
        description: 'Tubería rota en cocina',
        category: 'gasfiteria',
        budget: 60.0,
        district: 'Chiclayo',
      });

      expect(mockPrismaService.jobRequest.create).toHaveBeenCalled();
      expect(result.status).toBe(JobStatus.BUSCANDO);
      expect(result.id).toBe('job-test-1');
    });

    it('debe bloquear la publicación si el cliente tiene una chamba POR_CONFIRMAR', async () => {
      mockPrismaService.jobRequest.count.mockResolvedValue(1);

      await expect(
        service.createJob('user-client-1', {
          title: 'Otra chamba',
          description: 'Intento de publicación bloqueada',
          category: 'gasfiteria',
          budget: 50.0,
          district: 'Chiclayo',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('debe rechazar la publicación con presupuesto menor a S/ 20 (ALCANCE.md §3, L10)', async () => {
      mockPrismaService.jobRequest.count.mockResolvedValue(0);

      await expect(
        service.createJob('user-client-1', {
          title: 'Trabajo barato',
          description: 'Presupuesto por debajo del mínimo',
          category: 'gasfiteria',
          budget: 15.0,
          district: 'Chiclayo',
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('findAll', () => {
    it('debe listar chambas del cliente cuando role=client', async () => {
      mockPrismaService.jobRequest.findMany.mockResolvedValue([{ id: 'job-1', clientId: 'user-client-1' }]);

      const result = await service.findAll('user-client-1', { role: 'client' });
      expect(mockPrismaService.jobRequest.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ clientId: 'user-client-1' }),
        }),
      );
      expect(result).toHaveLength(1);
    });

    it('debe listar chambas disponibles (BUSCANDO, NEGOCIANDO) cuando role=worker', async () => {
      mockPrismaService.workerProfile.findUnique.mockResolvedValue({ id: 'wp-1', userId: 'user-worker-1' });
      mockPrismaService.jobRequest.findMany.mockResolvedValue([{ id: 'job-1', status: JobStatus.BUSCANDO }]);

      const result = await service.findAll('user-worker-1', { role: 'worker' });
      expect(result).toHaveLength(1);
    });
  });

  describe('createBid', () => {
    it('debe permitir a un técnico ofertar y cambiar la chamba a NEGOCIANDO', async () => {
      mockPrismaService.workerProfile.findUnique.mockResolvedValue({
        id: 'wp-1',
        userId: 'worker-user-1',
        rating: 4.8,
        completedJobs: 12,
        user: { fullName: 'Pedro Castillo', email: 'pedro@gmail.com' },
      });
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        id: 'job-1',
        status: JobStatus.BUSCANDO,
      });
      mockPrismaService.bid.create.mockResolvedValue({
        id: 'bid-1',
        jobRequestId: 'job-1',
        workerId: 'wp-1',
        amount: 70.0,
        message: 'Llego en 20m',
        status: 'PENDIENTE',
        createdAt: new Date(),
      });
      mockPrismaService.jobRequest.update.mockResolvedValue({
        id: 'job-1',
        status: JobStatus.NEGOCIANDO,
      });

      const bid = await service.createBid('worker-user-1', 'job-1', {
        amount: 70.0,
        message: 'Llego en 20m',
      });

      expect(bid.id).toBe('bid-1');
      expect(mockPrismaService.jobRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'job-1' },
          data: { status: JobStatus.NEGOCIANDO },
        }),
      );
      expect(mockEventsGateway.server.to).toHaveBeenCalledWith('job:job-1');
    });

    it('debe lanzar NotFoundException si el usuario no tiene perfil de trabajador', async () => {
      mockPrismaService.workerProfile.findUnique.mockResolvedValue(null);

      await expect(
        service.createBid('user-sin-perfil', 'job-1', { amount: 50.0 }),
      ).rejects.toThrow(NotFoundException);
    });

    it('debe lanzar BadRequestException si la chamba ya no está en BUSCANDO o NEGOCIANDO', async () => {
      mockPrismaService.workerProfile.findUnique.mockResolvedValue({ id: 'wp-1' });
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        id: 'job-1',
        status: JobStatus.ACEPTADA,
      });

      await expect(
        service.createBid('worker-user-1', 'job-1', { amount: 50.0 }),
      ).rejects.toThrow(BadRequestException);
    });

    it('debe rechazar ofertas menores a S/ 20 (ALCANCE.md §3, L10)', async () => {
      mockPrismaService.workerProfile.findUnique.mockResolvedValue({ id: 'wp-1' });
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        id: 'job-1',
        status: JobStatus.BUSCANDO,
      });

      await expect(
        service.createBid('worker-user-1', 'job-1', { amount: 15.0 }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('acceptBid', () => {
    it('debe permitir al cliente aceptar una oferta y pasar la chamba a ACEPTADA con plazo de 15 min', async () => {
      const mockJob = {
        id: 'job-1',
        clientId: 'client-user-1',
        status: JobStatus.NEGOCIANDO,
      };
      const mockBid = {
        id: 'bid-1',
        jobRequestId: 'job-1',
        workerId: 'wp-1',
        amount: 65.0,
        status: 'PENDIENTE',
      };
      mockPrismaService.jobRequest.findUnique.mockResolvedValue(mockJob);
      mockPrismaService.bid.findUnique.mockResolvedValue(mockBid);
      mockPrismaService.bid.update.mockResolvedValue({ ...mockBid, status: 'ACEPTADA' });
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...mockJob,
        status: JobStatus.ACEPTADA,
        workerId: 'wp-1',
        agreedPrice: 65.0,
      });

      const updatedJob = await service.acceptBid('client-user-1', 'job-1', 'bid-1');

      expect(updatedJob.status).toBe(JobStatus.ACEPTADA);
      expect(mockPrismaService.jobRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'job-1' },
          data: expect.objectContaining({
            status: JobStatus.ACEPTADA,
            workerId: 'wp-1',
            agreedPrice: 65.0,
          }),
        }),
      );
      expect(mockEventsGateway.server.to).toHaveBeenCalledWith('job:job-1');
    });

    it('debe lanzar ForbiddenException si quien acepta no es el dueño de la solicitud', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        id: 'job-1',
        clientId: 'client-user-1',
        status: JobStatus.NEGOCIANDO,
      });

      await expect(
        service.acceptBid('impostor-user', 'job-1', 'bid-1'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('updatePhase', () => {
    const baseJob = {
      id: 'job-phase-1',
      clientId: 'client-1',
      workerId: 'wp-1',
      status: JobStatus.ACEPTADA,
      securityPin: '4821',
      isPinVerified: false,
      beforePhotoUrl: null,
      afterPhotoUrl: null,
      worker: { id: 'wp-1', userId: 'worker-user-1' },
    };

    it('debe permitir al chambeador avanzar a EN_CAMINO desde ACEPTADA', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue(baseJob);
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_CAMINO,
      });

      const result = await service.updatePhase('worker-user-1', 'job-phase-1', {
        phase: JobStatus.EN_CAMINO,
      });

      expect(result.status).toBe(JobStatus.EN_CAMINO);
      expect(mockPrismaService.jobRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'job-phase-1' },
          data: expect.objectContaining({
            status: JobStatus.EN_CAMINO,
          }),
        }),
      );
      expect(mockEventsGateway.server.to).toHaveBeenCalledWith('job:job-phase-1');
    });

    it('debe permitir al chambeador avanzar a EN_SITIO desde EN_CAMINO', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_CAMINO,
      });
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_SITIO,
      });

      const result = await service.updatePhase('worker-user-1', 'job-phase-1', {
        phase: JobStatus.EN_SITIO,
      });

      expect(result.status).toBe(JobStatus.EN_SITIO);
    });

    it('debe requerir PIN válido y foto del antes para avanzar a EN_EJECUCION', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_SITIO,
      });
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_EJECUCION,
        isPinVerified: true,
        beforePhotoUrl: 'https://example.com/before.jpg',
      });

      const result = await service.updatePhase('worker-user-1', 'job-phase-1', {
        phase: JobStatus.EN_EJECUCION,
        pin: '4821',
        photoBefore: 'https://example.com/before.jpg',
      });

      expect(result.status).toBe(JobStatus.EN_EJECUCION);
      expect(mockPrismaService.jobRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            status: JobStatus.EN_EJECUCION,
            isPinVerified: true,
            beforePhotoUrl: 'https://example.com/before.jpg',
          }),
        }),
      );
    });

    it('debe rechazar EN_EJECUCION si el PIN es incorrecto', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_SITIO,
      });

      await expect(
        service.updatePhase('worker-user-1', 'job-phase-1', {
          phase: JobStatus.EN_EJECUCION,
          pin: '9999',
          photoBefore: 'https://example.com/before.jpg',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('debe rechazar EN_EJECUCION si falta la foto del antes', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_SITIO,
      });

      await expect(
        service.updatePhase('worker-user-1', 'job-phase-1', {
          phase: JobStatus.EN_EJECUCION,
          pin: '4821',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('debe requerir foto del después para avanzar a POR_CONFIRMAR', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_EJECUCION,
      });

      await expect(
        service.updatePhase('worker-user-1', 'job-phase-1', {
          phase: JobStatus.POR_CONFIRMAR,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('debe permitir avanzar a POR_CONFIRMAR con foto del después', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_EJECUCION,
      });
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.POR_CONFIRMAR,
        afterPhotoUrl: 'https://example.com/after.jpg',
      });

      const result = await service.updatePhase('worker-user-1', 'job-phase-1', {
        phase: JobStatus.POR_CONFIRMAR,
        photoAfter: 'https://example.com/after.jpg',
      });

      expect(result.status).toBe(JobStatus.POR_CONFIRMAR);
    });

    it('debe rechazar que el chambeador se auto-apruebe el trabajo a COMPLETADA', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...baseJob,
        status: JobStatus.POR_CONFIRMAR,
      });

      await expect(
        service.updatePhase('worker-user-1', 'job-phase-1', {
          phase: JobStatus.COMPLETADA,
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('debe rechazar que el cliente avance fases del chambeador', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue(baseJob);
      mockPrismaService.workerProfile.findUnique.mockResolvedValue(null);

      await expect(
        service.updatePhase('client-1', 'job-phase-1', {
          phase: JobStatus.EN_CAMINO,
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('debe permitir al cliente confirmar y pasar a COMPLETADA', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...baseJob,
        status: JobStatus.POR_CONFIRMAR,
      });
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.COMPLETADA,
      });

      const result = await service.updatePhase('client-1', 'job-phase-1', {
        phase: JobStatus.COMPLETADA,
      });

      expect(result.status).toBe(JobStatus.COMPLETADA);
      expect(mockPrismaService.jobRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            status: JobStatus.COMPLETADA,
            confirmedAt: expect.any(Date),
          }),
        }),
      );
    });
  });

  describe('autoReleaseExpiredConfirmedJobs (L5 - Confirmación 24h & L12)', () => {
    it('debe liberar automáticamente chambas en POR_CONFIRMAR con más de 24 horas y ejecutar releaseEscrow', async () => {
      const expiredJob = {
        id: 'job-expired-1',
        clientId: 'client-1',
        workerId: 'worker-1',
        status: JobStatus.POR_CONFIRMAR,
        updatedAt: new Date(Date.now() - 25 * 60 * 60 * 1000), // 25 horas atrás
        worker: {
          id: 'worker-1',
          userId: 'worker-user-1',
        },
      };

      mockPrismaService.jobRequest.findMany.mockResolvedValue([expiredJob]);
      mockPrismaService.ledgerEntry.findFirst.mockResolvedValue(null); // Sin liberación previa
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...expiredJob,
        status: JobStatus.COMPLETADA,
        confirmedAt: new Date(),
      });

      const released = await service.autoReleaseExpiredConfirmedJobs(24);

      expect(mockPrismaService.jobRequest.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            status: JobStatus.POR_CONFIRMAR,
          }),
        }),
      );
      expect(mockFinanceService.releaseEscrow).toHaveBeenCalledWith(
        'client-1',
        'worker-user-1',
        'job-expired-1',
      );
      expect(mockPrismaService.jobRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'job-expired-1' },
          data: expect.objectContaining({
            status: JobStatus.COMPLETADA,
            confirmedAt: expect.any(Date),
          }),
        }),
      );
      expect(mockEventsGateway.server.to).toHaveBeenCalledWith('job:job-expired-1');
      expect(released).toHaveLength(1);
      expect(released[0].status).toBe(JobStatus.COMPLETADA);
    });

    it('no debe liberar trabajos si aún no han transcurrido 24 horas', async () => {
      // Si la consulta en BD no retorna registros (porque updatedAt no cumple el threshold de 24h)
      mockPrismaService.jobRequest.findMany.mockResolvedValue([]);

      const released = await service.autoReleaseExpiredConfirmedJobs(24);

      expect(released).toHaveLength(0);
      expect(mockFinanceService.releaseEscrow).not.toHaveBeenCalled();
      expect(mockPrismaService.jobRequest.update).not.toHaveBeenCalled();
    });

    it('no debe liberar trabajos que se encuentren en EN_DISPUTA', async () => {
      const disputeJob = {
        id: 'job-dispute-1',
        clientId: 'client-1',
        workerId: 'worker-1',
        status: JobStatus.EN_DISPUTA,
        updatedAt: new Date(Date.now() - 30 * 60 * 60 * 1000),
        worker: { id: 'worker-1', userId: 'worker-user-1' },
      };

      mockPrismaService.jobRequest.findMany.mockResolvedValue([disputeJob]);

      const released = await service.autoReleaseExpiredConfirmedJobs(24);

      expect(released).toHaveLength(0);
      expect(mockFinanceService.releaseEscrow).not.toHaveBeenCalled();
      expect(mockPrismaService.jobRequest.update).not.toHaveBeenCalled();
    });

    it('idempotencia estricta: doble ejecución no duplica liberación ni asientos', async () => {
      const expiredJob = {
        id: 'job-already-paid',
        clientId: 'client-1',
        workerId: 'worker-1',
        status: JobStatus.POR_CONFIRMAR,
        updatedAt: new Date(Date.now() - 26 * 60 * 60 * 1000),
        worker: { id: 'worker-1', userId: 'worker-user-1' },
      };

      mockPrismaService.jobRequest.findMany.mockResolvedValue([expiredJob]);
      // Simular que ya existe un asiento RELEASE_ESCROW en el ledger
      mockPrismaService.ledgerEntry.findFirst.mockResolvedValue({
        id: 'entry-released-1',
        type: 'RELEASE_ESCROW',
        jobRequestId: 'job-already-paid',
      });

      const released = await service.autoReleaseExpiredConfirmedJobs(24);

      // Debe omitir la liberación y retornar 0 trabajos liberados en la segunda ejecución
      expect(released).toHaveLength(0);
      expect(mockFinanceService.releaseEscrow).not.toHaveBeenCalled();
      expect(mockPrismaService.jobRequest.update).not.toHaveBeenCalled();
    });

    it('modificar el trabajo con updatedAt reciente no reinicia las 24 h si autoReleaseAt ya venció', async () => {
      const expiredJob = {
        id: 'job-updated-recently',
        clientId: 'client-1',
        workerId: 'worker-1',
        status: JobStatus.POR_CONFIRMAR,
        autoReleaseAt: new Date(Date.now() - 1000), // autoReleaseAt fijado al pasar a POR_CONFIRMAR ya venció
        updatedAt: new Date(), // Simula una modificación reciente que no debe reiniciar el plazo
        worker: {
          id: 'worker-1',
          userId: 'worker-user-1',
        },
      };

      mockPrismaService.jobRequest.findMany.mockResolvedValue([expiredJob]);
      mockPrismaService.ledgerEntry.findFirst.mockResolvedValue(null);
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...expiredJob,
        status: JobStatus.COMPLETADA,
        confirmedAt: new Date(),
      });

      const released = await service.autoReleaseExpiredConfirmedJobs(24);

      expect(released).toHaveLength(1);
      expect(mockFinanceService.releaseEscrow).toHaveBeenCalledWith(
        'client-1',
        'worker-user-1',
        'job-updated-recently',
      );
    });
  });

  describe('cancelJob (L6 - Cancelación y Reglas de §4)', () => {
    const baseJob = {
      id: 'job-cancel-1',
      clientId: 'client-1',
      workerId: 'worker-prof-1',
      status: JobStatus.BUSCANDO,
      worker: {
        id: 'worker-prof-1',
        userId: 'worker-user-1',
      },
    };

    it('debe cancelar sin movimiento financiero si no hay depósito en custodia', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue(baseJob);
      mockPrismaService.ledgerEntry.findFirst.mockResolvedValue(null);
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.CANCELADA,
      });

      const result = await service.cancelJob('client-1', 'job-cancel-1', {
        reason: 'Ya no requiero el servicio',
      });

      expect(result.job.status).toBe(JobStatus.CANCELADA);
      expect(mockFinanceService.refundEscrow).not.toHaveBeenCalled();
    });

    it('debe otorgar compensación al técnico si el cliente cancela cuando el técnico está EN_CAMINO', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_CAMINO,
      });
      mockPrismaService.ledgerEntry.findFirst.mockResolvedValue({ id: 'hold-1' });
      mockFinanceService.refundEscrow.mockResolvedValue({
        totalCustody: 102.0,
        refundAmount: 92.0,
        compensation: 10.0,
      });
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.CANCELADA,
      });

      const result = await service.cancelJob('client-1', 'job-cancel-1', {
        reason: 'Emergencia cancelada por imprevisto familiar',
      });

      expect(mockFinanceService.refundEscrow).toHaveBeenCalledWith(
        'client-1',
        'job-cancel-1',
        true,
        'worker-user-1',
      );
      expect(result.job.status).toBe(JobStatus.CANCELADA);
    });

    it('debe registrar incidente de reputación al técnico si no llega (>30 min retraso)', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_CAMINO,
      });
      mockPrismaService.ledgerEntry.findFirst.mockResolvedValue({ id: 'hold-1' });
      mockFinanceService.refundEscrow.mockResolvedValue({
        totalCustody: 102.0,
        refundAmount: 102.0,
        compensation: 0.0,
      });
      mockPrismaService.workerProfile.update.mockResolvedValue({
        id: 'worker-prof-1',
        incidentsCount: 1,
      });
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.CANCELADA,
      });

      await service.cancelJob('client-1', 'job-cancel-1', {
        reason: 'Técnico no llegó pasados 35 minutos',
        isWorkerDelay: true,
      });

      expect(mockFinanceService.refundEscrow).toHaveBeenCalledWith(
        'client-1',
        'job-cancel-1',
        false,
      );
      expect(mockPrismaService.workerProfile.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'worker-prof-1' },
          data: { incidentsCount: { increment: 1 } },
        }),
      );
    });

    it('debe suspender al técnico si acumula 3 o más incidentes de reputación', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_CAMINO,
      });
      mockPrismaService.ledgerEntry.findFirst.mockResolvedValue({ id: 'hold-1' });
      mockFinanceService.refundEscrow.mockResolvedValue({
        totalCustody: 102.0,
        refundAmount: 102.0,
        compensation: 0.0,
      });
      mockPrismaService.workerProfile.update.mockResolvedValue({
        id: 'worker-prof-1',
        incidentsCount: 3,
      });
      mockPrismaService.user.update.mockResolvedValue({ id: 'worker-user-1', status: 'SUSPENDED' });
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.CANCELADA,
      });

      await service.cancelJob('client-1', 'job-cancel-1', {
        reason: 'Técnico canceló o no se presentó',
        isWorkerDelay: true,
      });

      expect(mockPrismaService.user.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'worker-user-1' },
          data: { status: 'SUSPENDED' },
        }),
      );
    });

    it('debe rechazar cancelación directa si el PIN ya fue validado (EN_EJECUCION en adelante)', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_EJECUCION,
      });

      await expect(
        service.cancelJob('client-1', 'job-cancel-1', {
          reason: 'Quiero cancelar a mitad de trabajo',
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('createRating & getJobReceipt (L8 — Calificación, recibo y notificaciones)', () => {
    const completedJob = {
      id: 'job-l8-101',
      title: 'Reparación de cañería en cocina',
      category: 'gasfiteria',
      clientId: 'client-1',
      workerId: 'worker-prof-1',
      budget: 100.0,
      status: JobStatus.COMPLETADA,
      isPinVerified: true,
      beforePhotoUrl: 'https://chamba.pe/photos/before.jpg',
      afterPhotoUrl: 'https://chamba.pe/photos/after.jpg',
      district: 'Santa Victoria, Chiclayo',
      confirmedAt: new Date('2026-11-09T18:00:00Z'),
      client: {
        id: 'client-1',
        fullName: 'Lucía Fernández',
      },
      worker: {
        id: 'worker-prof-1',
        userId: 'worker-user-1',
        user: {
          fullName: 'Jorge Quispe Baldera',
        },
      },
    };

    it('debe permitir al cliente calificar al técnico con 5 estrellas, comentario y propina', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue(completedJob);
      const createdRating = {
        id: 'rating-1',
        jobRequestId: 'job-l8-101',
        fromUserId: 'client-1',
        toUserId: 'worker-user-1',
        stars: 5,
        comment: 'Excelente servicio, muy puntual y limpio.',
        tipAmount: 10.0,
        createdAt: new Date(),
      };
      mockPrismaService.rating.create.mockResolvedValue(createdRating);
      mockPrismaService.rating.findMany.mockResolvedValue([{ stars: 5 }, { stars: 5 }]);
      mockPrismaService.workerProfile.update.mockResolvedValue({ id: 'worker-prof-1', rating: 5.0 });

      const result = await service.createRating('client-1', 'job-l8-101', {
        stars: 5,
        comment: 'Excelente servicio, muy puntual y limpio.',
        tipAmount: 10.0,
      });

      expect(result.stars).toBe(5);
      expect(result.tipAmount).toBe(10.0);
      expect(mockPrismaService.rating.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            fromUserId: 'client-1',
            toUserId: 'worker-user-1',
            stars: 5,
            tipAmount: 10.0,
          }),
        }),
      );
    });

    it('debe permitir al técnico calificar al cliente de vuelta', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue(completedJob);
      const createdRating = {
        id: 'rating-2',
        jobRequestId: 'job-l8-101',
        fromUserId: 'worker-user-1',
        toUserId: 'client-1',
        stars: 5,
        comment: 'Excelente cliente, pago oportuno y buen trato.',
        tipAmount: 0,
        createdAt: new Date(),
      };
      mockPrismaService.rating.create.mockResolvedValue(createdRating);
      mockPrismaService.rating.findMany.mockResolvedValue([{ stars: 5 }]);

      const result = await service.createRating('worker-user-1', 'job-l8-101', {
        stars: 5,
        comment: 'Excelente cliente, pago oportuno y buen trato.',
      });

      expect(result.toUserId).toBe('client-1');
      expect(result.stars).toBe(5);
    });

    it('debe rechazar calificar una chamba que no esté en estado COMPLETADA', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue({
        ...completedJob,
        status: JobStatus.EN_CAMINO,
      });

      await expect(
        service.createRating('client-1', 'job-l8-101', {
          stars: 5,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('debe generar el recibo detallado con precio, comisión 8%, tarifa S/ 2 y fotos', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue(completedJob);
      mockPrismaService.rating.findMany.mockResolvedValue([
        { tipAmount: 10.0 },
      ]);

      const receipt = await service.getJobReceipt('job-l8-101');

      expect(receipt.jobId).toBe('job-l8-101');
      expect(receipt.agreedPrice).toBe(100.0);
      expect(receipt.commission).toBe(8.0); // 8% de 100
      expect(receipt.serviceFee).toBe(2.0); // S/ 2 fijo
      expect(receipt.totalPaidByClient).toBe(112.0); // 100 + 2 + 10 tip
      expect(receipt.totalReceivedByWorker).toBe(102.0); // (100 - 8) + 10 tip
      expect(receipt.beforePhotoUrl).toBe('https://chamba.pe/photos/before.jpg');
      expect(receipt.afterPhotoUrl).toBe('https://chamba.pe/photos/after.jpg');
    });
  });

  describe('Control de acceso y privacidad en jobs y recibo (ALCANCE.md §8 L14)', () => {
    const jobWithSensitiveData = {
      id: 'job-sec-101',
      title: 'Reparación de cerradura principal',
      category: 'cerrajeria',
      clientId: 'client-1',
      workerId: 'worker-prof-1',
      budget: 100.0,
      status: JobStatus.BUSCANDO,
      securityPin: '4821',
      district: 'Chiclayo Centro',
      client: {
        id: 'client-1',
        fullName: 'Lucía Fernández',
        email: 'lucia@chamba.pe',
        phone: '979111222',
        district: 'Chiclayo Centro',
        address: 'Calle San José 456, Int 2B',
      },
      worker: {
        id: 'worker-prof-1',
        user: {
          id: 'worker-user-1',
          fullName: 'Jorge Cerrajero',
          phone: '988333444',
        },
      },
      bids: [],
    };

    describe('findOne - Privacidad y protección de datos', () => {
      it('el cliente ve su PIN, dirección exacta y teléfono, pero el correo no se expone a terceros', async () => {
        mockPrismaService.jobRequest.findUnique.mockResolvedValue(jobWithSensitiveData);

        const res = await service.findOne('job-sec-101', { id: 'client-1', role: 'CLIENT' });

        expect(res.securityPin).toBe('4821');
        expect(res.client.address).toBe('Calle San José 456, Int 2B');
        expect(res.client.phone).toBe('979111222');
        expect(res.client.email).toBeUndefined();
      });

      it('un trabajador en búsqueda/negociación ve distrito pero NUNCA ve PIN, dirección exacta ni correo', async () => {
        mockPrismaService.jobRequest.findUnique.mockResolvedValue({
          ...jobWithSensitiveData,
          status: JobStatus.BUSCANDO,
        });

        const res = await service.findOne('job-sec-101', { id: 'worker-user-1', role: 'WORKER' });

        expect(res.securityPin).toBeNull();
        expect(res.client.district).toBe('Chiclayo Centro');
        expect(res.client.address).toBeUndefined();
        expect(res.client.phone).toBeUndefined();
        expect(res.client.email).toBeUndefined();
      });

      it('el trabajador asignado tras el depósito (EN_CAMINO) ve dirección exacta y teléfono, pero NUNCA el PIN', async () => {
        mockPrismaService.jobRequest.findUnique.mockResolvedValue({
          ...jobWithSensitiveData,
          status: JobStatus.EN_CAMINO,
        });

        const res = await service.findOne('job-sec-101', { id: 'worker-user-1', role: 'WORKER' });

        expect(res.securityPin).toBeNull(); // NUNCA el PIN
        expect(res.client.address).toBe('Calle San José 456, Int 2B');
        expect(res.client.phone).toBe('979111222');
        expect(res.client.email).toBeUndefined();
      });

      it('personal de soporte ve PIN, dirección, teléfono y correo para auditoría', async () => {
        mockPrismaService.jobRequest.findUnique.mockResolvedValue(jobWithSensitiveData);

        const res = await service.findOne('job-sec-101', { id: 'support-1', role: 'SUPPORT' });

        expect(res.securityPin).toBe('4821');
        expect(res.client.address).toBe('Calle San José 456, Int 2B');
        expect(res.client.phone).toBe('979111222');
        expect(res.client.email).toBe('lucia@chamba.pe');
      });
    });

    describe('createBid - Validación de postulación propia', () => {
      it('debe rechazar con 403 Forbidden si el cliente intenta ofertar en su propia chamba', async () => {
        mockPrismaService.workerProfile.findUnique.mockResolvedValue({
          id: 'worker-prof-self',
          userId: 'client-1',
          user: { fullName: 'Lucía Cliente' },
        });
        mockPrismaService.jobRequest.findUnique.mockResolvedValue(jobWithSensitiveData);

        await expect(
          service.createBid('client-1', 'job-sec-101', {
            amount: 50.0,
            message: 'Me auto-postulo',
          }),
        ).rejects.toThrow(ForbiddenException);
      });
    });

    describe('counterBid - Validación de pertenencia', () => {
      it('debe rechazar con 403 Forbidden si un tercero intenta contraofertar', async () => {
        mockPrismaService.bid.findUnique.mockResolvedValue({
          id: 'bid-1',
          jobRequestId: 'job-sec-101',
          workerId: 'worker-prof-1',
          worker: { userId: 'worker-user-1' },
          jobRequest: { clientId: 'client-1' },
        });

        await expect(
          service.counterBid('intruder-user', 'job-sec-101', 'bid-1', {
            counterAmount: 80.0,
          }),
        ).rejects.toThrow(ForbiddenException);
      });
    });

    describe('getJobReceipt - Control de acceso y privacidad', () => {
      const completedJobForReceipt = {
        id: 'job-receipt-1',
        title: 'Chamba culminada',
        category: 'electricidad',
        clientId: 'client-1',
        workerId: 'worker-prof-1',
        budget: 100.0,
        status: JobStatus.COMPLETADA,
        district: 'Chiclayo',
        client: { fullName: 'Lucía Fernández' },
        worker: { user: { id: 'worker-user-1', fullName: 'Jorge Técnico' } },
      };

      it('debe rechazar con 403 si un tercero no autorizado consulta el recibo', async () => {
        mockPrismaService.jobRequest.findUnique.mockResolvedValue(completedJobForReceipt);

        await expect(
          service.getJobReceipt('job-receipt-1', { id: 'stranger-user', role: 'CLIENT' }),
        ).rejects.toThrow(ForbiddenException);
      });

      it('cliente ve desglose de su pago y la comisión del técnico queda oculta', async () => {
        mockPrismaService.jobRequest.findUnique.mockResolvedValue(completedJobForReceipt);
        mockPrismaService.rating.findMany.mockResolvedValue([{ tipAmount: 5.0 }]);

        const receipt = await service.getJobReceipt('job-receipt-1', {
          id: 'client-1',
          role: 'CLIENT',
        });

        expect(receipt.agreedPrice).toBe(100.0);
        expect(receipt.serviceFee).toBe(2.0);
        expect(receipt.totalPaidByClient).toBe(107.0);
        expect(receipt.commission).toBeNull();
        expect(receipt.totalReceivedByWorker).toBeNull();
      });

      it('técnico ve su liquidación y la tarifa cobrada al cliente queda oculta', async () => {
        mockPrismaService.jobRequest.findUnique.mockResolvedValue(completedJobForReceipt);
        mockPrismaService.rating.findMany.mockResolvedValue([{ tipAmount: 5.0 }]);

        const receipt = await service.getJobReceipt('job-receipt-1', {
          id: 'worker-user-1',
          role: 'WORKER',
        });

        expect(receipt.agreedPrice).toBe(100.0);
        expect(receipt.commission).toBe(8.0);
        expect(receipt.totalReceivedByWorker).toBe(97.0);
        expect(receipt.serviceFee).toBeNull();
        expect(receipt.totalPaidByClient).toBeNull();
      });

      it('personal de soporte ve recibo y liquidación completos', async () => {
        mockPrismaService.jobRequest.findUnique.mockResolvedValue(completedJobForReceipt);
        mockPrismaService.rating.findMany.mockResolvedValue([{ tipAmount: 5.0 }]);

        const receipt = await service.getJobReceipt('job-receipt-1', {
          id: 'support-1',
          role: 'SUPPORT',
        });

        expect(receipt.serviceFee).toBe(2.0);
        expect(receipt.commission).toBe(8.0);
        expect(receipt.totalPaidByClient).toBe(107.0);
        expect(receipt.totalReceivedByWorker).toBe(97.0);
      });
    });
  });
});
