import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { DisputesService } from './disputes.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { EventsGateway } from '../events/events.gateway.js';
import { FinanceService } from '../finance/finance.service.js';
import { JobStatus } from '../common/job-state-machine.js';
import { DisputeVerdict } from './dto/resolve-dispute.dto.js';

describe('DisputesService (Unit Tests — ALCANCE.md §5, §8 L7)', () => {
  let service: DisputesService;

  const mockPrismaService = {
    jobRequest: {
      findUnique: vi.fn(),
      update: vi.fn(),
    },
    user: {
      findUnique: vi.fn(),
    },
    dispute: {
      create: vi.fn(),
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      update: vi.fn(),
    },
    supportTicket: {
      create: vi.fn(),
      updateMany: vi.fn(),
    },
    ledgerEntry: {
      findFirst: vi.fn(),
    },
    $transaction: vi.fn((callback) => callback(mockPrismaService)),
  };

  const mockFinanceService = {
    releaseEscrow: vi.fn(),
    refundEscrow: vi.fn(),
    resolveDisputeEscrow: vi.fn(),
    getJobFinancialAudit: vi.fn().mockResolvedValue({
      totalCustody: 52.0,
      refundClient: 25.0,
      amountToWorker: 23.0,
      commission: 2.0,
      serviceFee: 2.0,
      invariantPassed: true,
      invariantFormula: '52.00 = 25.00 + 23.00 + 2.00 + 2.00',
      entries: [],
    }),
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
        DisputesService,
        {
          provide: PrismaService,
          useValue: mockPrismaService,
        },
        {
          provide: FinanceService,
          useValue: mockFinanceService,
        },
        {
          provide: EventsGateway,
          useValue: mockEventsGateway,
        },
      ],
    }).compile();

    service = module.get<DisputesService>(DisputesService);
  });

  const baseJob = {
    id: 'job-disp-101',
    title: 'Reparación de filtración de tubería',
    clientId: 'user-client-1',
    workerId: 'worker-prof-1',
    budget: 100.0,
    status: JobStatus.POR_CONFIRMAR,
    isPinVerified: true,
    beforePhotoUrl: 'https://chamba.pe/photos/before.jpg',
    afterPhotoUrl: 'https://chamba.pe/photos/after.jpg',
    worker: {
      id: 'worker-prof-1',
      userId: 'user-worker-1',
    },
  };

  describe('openDispute', () => {
    it('debe abrir disputa, congelar fondos pasando a EN_DISPUTA y crear ticket de soporte', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue(baseJob);
      mockPrismaService.dispute.findFirst.mockResolvedValue(null);

      const createdDispute = {
        id: 'disp-001',
        jobRequestId: 'job-disp-101',
        openedById: 'user-client-1',
        reason: 'El trabajo no quedó bien sellado y sigue goteando',
        status: 'ABIERTA',
        createdAt: new Date(),
      };
      mockPrismaService.dispute.create.mockResolvedValue(createdDispute);
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.EN_DISPUTA,
      });
      mockPrismaService.supportTicket.create.mockResolvedValue({
        id: 'ticket-001',
        status: 'ABIERTO',
      });

      const result = await service.openDispute('user-client-1', 'job-disp-101', {
        reason: 'El trabajo no quedó bien sellado y sigue goteando',
        statement: 'Al abrir la llave principal el agua sigue saliendo por el codo.',
      });

      expect(mockPrismaService.jobRequest.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'job-disp-101' },
          data: { status: JobStatus.EN_DISPUTA },
        }),
      );
      expect(mockPrismaService.dispute.create).toHaveBeenCalled();
      expect(mockPrismaService.supportTicket.create).toHaveBeenCalled();
      expect(result.dispute.id).toBe('disp-001');
    });

    it('debe rechazar abrir disputa a un usuario ajeno a la chamba', async () => {
      mockPrismaService.jobRequest.findUnique.mockResolvedValue(baseJob);

      await expect(
        service.openDispute('user-intruso', 'job-disp-101', {
          reason: 'Razon no autorizada',
          statement: 'Declaracion',
        }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('IA Recommendation (recomienda, nunca ejecuta sola)', () => {
    it('debe generar recomendación con justificación sin mover dinero por su cuenta', async () => {
      const disputeWithJob = {
        id: 'disp-001',
        jobRequestId: 'job-disp-101',
        reason: 'Trabajo no concluido',
        clientStatement: 'Falta ajustar la llave',
        workerStatement: 'El trabajo fue entregado probado',
        jobRequest: baseJob,
      };

      mockPrismaService.dispute.findUnique.mockResolvedValue(disputeWithJob);
      mockPrismaService.dispute.update.mockImplementation(({ data }) => ({
        ...disputeWithJob,
        ...data,
      }));

      const recommendation = await service.generateAiRecommendation('disp-001');

      expect(recommendation).toHaveProperty('verdict');
      expect(recommendation).toHaveProperty('confidence');
      expect(recommendation).toHaveProperty('justification');
      // REGLA DURA: La IA nunca debe llamar a releaseEscrow o refundEscrow
      expect(mockFinanceService.releaseEscrow).not.toHaveBeenCalled();
      expect(mockFinanceService.refundEscrow).not.toHaveBeenCalled();
    });
  });

  describe('resolveDispute (aprobación humana por soporte)', () => {
    const activeDispute = {
      id: 'disp-001',
      jobRequestId: 'job-disp-101',
      status: 'ABIERTA',
      jobRequest: baseJob,
    };

    it('debe resolver liberando al técnico cuando soporte aprueba RELEASE_WORKER', async () => {
      mockPrismaService.dispute.findUnique.mockResolvedValue(activeDispute);
      mockPrismaService.dispute.update.mockResolvedValue({
        ...activeDispute,
        status: 'RESUELTA_TRABAJADOR',
      });
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.COMPLETADA,
      });
      mockPrismaService.user.findUnique.mockResolvedValue({
        id: 'support-agent-1',
        email: 'soporte@chamba.pe',
        fullName: 'Agente Soporte',
        role: 'SUPPORT',
      });
      mockFinanceService.resolveDisputeEscrow.mockResolvedValue({
        success: true,
        totalCustody: 52.0,
        refundClient: 0,
        amountToWorker: 46.0,
        commission: 4.0,
        serviceFee: 2.0,
      });

      const res = await service.resolveDispute('support-agent-1', 'disp-001', {
        verdict: DisputeVerdict.RELEASE_WORKER,
        notes: 'Fotos de antes y después y PIN validado confirman ejecución conforme.',
      });

      expect(mockFinanceService.resolveDisputeEscrow).toHaveBeenCalledWith(
        'user-client-1',
        'user-worker-1',
        'job-disp-101',
        DisputeVerdict.RELEASE_WORKER,
        50,
      );
      expect(res.dispute.status).toBe('RESUELTA_TRABAJADOR');
      expect(res.resolvedBy.email).toBe('soporte@chamba.pe');
    });

    it('debe resolver reembolsando al cliente cuando soporte aprueba REFUND_CLIENT', async () => {
      mockPrismaService.dispute.findUnique.mockResolvedValue(activeDispute);
      mockPrismaService.dispute.update.mockResolvedValue({
        ...activeDispute,
        status: 'RESUELTA_CLIENTE',
      });
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.CANCELADA,
      });
      mockPrismaService.user.findUnique.mockResolvedValue({
        id: 'support-agent-1',
        email: 'soporte@chamba.pe',
        fullName: 'Agente Soporte',
        role: 'SUPPORT',
      });
      mockFinanceService.resolveDisputeEscrow.mockResolvedValue({
        success: true,
        totalCustody: 52.0,
        refundClient: 52.0,
        amountToWorker: 0,
        commission: 0,
        serviceFee: 0,
      });

      const res = await service.resolveDispute('support-agent-1', 'disp-001', {
        verdict: DisputeVerdict.REFUND_CLIENT,
        notes: 'Evidencia demuestra que no se solucionó la fuga.',
      });

      expect(mockFinanceService.resolveDisputeEscrow).toHaveBeenCalledWith(
        'user-client-1',
        'user-worker-1',
        'job-disp-101',
        DisputeVerdict.REFUND_CLIENT,
        50,
      );
      expect(res.dispute.status).toBe('RESUELTA_CLIENTE');
    });

    it('debe resolver dividiendo al 50/50 cuando soporte aprueba SPLIT (§5, §8 L13)', async () => {
      mockPrismaService.dispute.findUnique.mockResolvedValue(activeDispute);
      mockPrismaService.dispute.update.mockResolvedValue({
        ...activeDispute,
        status: 'RESUELTA_DIVIDIDA',
      });
      mockPrismaService.jobRequest.update.mockResolvedValue({
        ...baseJob,
        status: JobStatus.COMPLETADA,
      });
      mockPrismaService.user.findUnique.mockResolvedValue({
        id: 'support-agent-1',
        email: 'soporte@chamba.pe',
        fullName: 'Agente Soporte',
        role: 'SUPPORT',
      });
      mockFinanceService.resolveDisputeEscrow.mockResolvedValue({
        success: true,
        totalCustody: 52.0,
        refundClient: 25.0,
        amountToWorker: 23.0,
        commission: 2.0,
        serviceFee: 2.0,
      });

      const res = await service.resolveDispute('support-agent-1', 'disp-001', {
        verdict: DisputeVerdict.SPLIT,
        workerSplitPercent: 50,
        notes: 'Intervención parcial: se divide 50/50.',
      });

      expect(mockFinanceService.resolveDisputeEscrow).toHaveBeenCalledWith(
        'user-client-1',
        'user-worker-1',
        'job-disp-101',
        DisputeVerdict.SPLIT,
        50,
      );
      expect(res.dispute.status).toBe('RESUELTA_DIVIDIDA');
      expect(res.settlement.refundClient).toBe(25.0);
      expect(res.settlement.amountToWorker).toBe(23.0);
      expect(res.settlement.commission).toBe(2.0);
      expect(res.settlement.serviceFee).toBe(2.0);
    });

    it('debe rechazar con 403 Forbidden si el cliente de la disputa intenta resolverla él mismo (ALCANCE.md §8 L12)', async () => {
      mockPrismaService.dispute.findUnique.mockResolvedValue(activeDispute);

      await expect(
        service.resolveDispute('user-client-1', 'disp-001', {
          verdict: DisputeVerdict.REFUND_CLIENT,
          notes: 'Intento de auto-resolución por el cliente',
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('debe rechazar con 403 Forbidden si el técnico de la disputa intenta resolverla él mismo (ALCANCE.md §8 L12)', async () => {
      mockPrismaService.dispute.findUnique.mockResolvedValue(activeDispute);

      await expect(
        service.resolveDispute('user-worker-1', 'disp-001', {
          verdict: DisputeVerdict.RELEASE_WORKER,
          notes: 'Intento de auto-resolución por el técnico',
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('debe rechazar con 403 Forbidden si la parte involucrada intenta solicitar recomendación de IA', async () => {
      mockPrismaService.dispute.findUnique.mockResolvedValue(activeDispute);

      await expect(
        service.generateAiRecommendation('disp-001', 'user-client-1'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('appealDispute (una sola apelación permitida)', () => {
    it('debe admitir una primera apelación con evidencia nueva', async () => {
      const resolvedDispute = {
        id: 'disp-001',
        status: 'RESUELTA_CLIENTE',
        appealsCount: 0,
        jobRequest: baseJob,
      };

      mockPrismaService.dispute.findUnique.mockResolvedValue(resolvedDispute);
      mockPrismaService.dispute.update.mockResolvedValue({
        ...resolvedDispute,
        status: 'EN_REVISION',
        appealsCount: 1,
      });

      const result = await service.appealDispute('user-worker-1', 'disp-001', {
        appealReason: 'Tengo video que demuestra funcionamiento previo a la salida',
        newEvidence: 'https://chamba.pe/videos/prueba_final.mp4',
      });

      expect(result.appealsCount).toBe(1);
      expect(result.status).toBe('EN_REVISION');
    });

    it('debe rechazar una segunda apelación', async () => {
      const alreadyAppealedDispute = {
        id: 'disp-001',
        status: 'RESUELTA_CLIENTE',
        appealsCount: 1,
        jobRequest: baseJob,
      };

      mockPrismaService.dispute.findUnique.mockResolvedValue(alreadyAppealedDispute);

      await expect(
        service.appealDispute('user-worker-1', 'disp-001', {
          appealReason: 'Intento de segunda apelación',
          newEvidence: 'evidencia_extra',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('debe rechazar con 403 si un tercero ajeno a la disputa intenta apelar (ALCANCE.md §8 L14)', async () => {
      const resolvedDispute = {
        id: 'disp-001',
        status: 'RESUELTA_CLIENTE',
        appealsCount: 0,
        jobRequest: baseJob,
      };

      mockPrismaService.dispute.findUnique.mockResolvedValue(resolvedDispute);

      await expect(
        service.appealDispute('user-stranger-999', 'disp-001', {
          appealReason: 'Intrusión externa',
        }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('Control de acceso y privacidad en lectura de disputas (ALCANCE.md §8 L14)', () => {
    const disputeWithUsers = {
      id: 'disp-privacy-1',
      jobRequestId: 'job-disp-101',
      status: 'RESUELTA_DIVIDIDA',
      resolvedById: 'support-user-1',
      jobRequest: baseJob,
      openedBy: {
        id: 'user-client-1',
        fullName: 'Ana Cliente',
        email: 'ana@chamba.pe',
      },
    };

    const resolverUser = {
      id: 'support-user-1',
      fullName: 'Operador de Soporte',
      email: 'soporte@chamba.pe',
      role: 'SUPPORT',
    };

    it('debe lanzar 403 si un tercero no autorizado consulta getDisputeById', async () => {
      mockPrismaService.dispute.findUnique.mockResolvedValue(disputeWithUsers);

      await expect(
        service.getDisputeById('disp-privacy-1', { id: 'stranger-user', role: 'CLIENT' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('debe lanzar 403 si un tercero no autorizado consulta getDisputeByJobId', async () => {
      mockPrismaService.dispute.findFirst.mockResolvedValue(disputeWithUsers);

      await expect(
        service.getDisputeByJobId('job-disp-101', { id: 'stranger-user', role: 'CLIENT' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('el cliente ve nombres pero los correos se ofuscan/omiten por privacidad', async () => {
      mockPrismaService.dispute.findUnique.mockResolvedValue(disputeWithUsers);
      mockPrismaService.user.findUnique.mockResolvedValue(resolverUser);

      const res = await service.getDisputeById('disp-privacy-1', {
        id: 'user-client-1',
        role: 'CLIENT',
      });

      expect(res.dispute.openedBy.fullName).toBe('Ana Cliente');
      expect((res.dispute.openedBy as any).email).toBeUndefined();
      expect(res.resolvedBy.fullName).toBe('Operador de Soporte');
      expect((res.resolvedBy as any).email).toBeUndefined();
    });

    it('el técnico ve nombres pero los correos se ofuscan/omiten por privacidad', async () => {
      mockPrismaService.dispute.findUnique.mockResolvedValue(disputeWithUsers);
      mockPrismaService.user.findUnique.mockResolvedValue(resolverUser);

      const res = await service.getDisputeById('disp-privacy-1', {
        id: 'user-worker-1',
        role: 'WORKER',
      });

      expect(res.dispute.openedBy.fullName).toBe('Ana Cliente');
      expect((res.dispute.openedBy as any).email).toBeUndefined();
      expect(res.resolvedBy.fullName).toBe('Operador de Soporte');
      expect((res.resolvedBy as any).email).toBeUndefined();
    });

    it('el personal de soporte ve correos y auditoría completa', async () => {
      mockPrismaService.dispute.findUnique.mockResolvedValue(disputeWithUsers);
      mockPrismaService.user.findUnique.mockResolvedValue(resolverUser);

      const res = await service.getDisputeById('disp-privacy-1', {
        id: 'support-user-1',
        role: 'SUPPORT',
      });

      expect(res.dispute.openedBy.email).toBe('ana@chamba.pe');
      expect(res.resolvedBy.email).toBe('soporte@chamba.pe');
    });
  });
});

