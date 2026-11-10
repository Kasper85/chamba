import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import { FinanceService } from './finance.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

describe('FinanceService (Unit Tests)', () => {
  let service: FinanceService;

  const mockWallet = {
    id: 'wallet-client-1',
    userId: 'user-client-1',
  };

  const mockWorkerWallet = {
    id: 'wallet-worker-1',
    userId: 'user-worker-1',
  };

  const mockPlatformWallet = {
    id: 'wallet-platform-treasury',
    userId: 'platform-treasury',
  };

  const mockPrisma = {
    user: {
      findFirst: vi.fn(),
      create: vi.fn(),
    },
    wallet: {
      upsert: vi.fn(),
    },
    jobRequest: {
      findUnique: vi.fn(),
    },
    ledgerEntry: {
      findFirst: vi.fn(),
      create: vi.fn(),
      findMany: vi.fn(),
    },
    $queryRaw: vi.fn(),
    $transaction: vi.fn(),
  };

  const mockConfigService = {
    get: vi.fn().mockImplementation((key: string, defaultVal: string) => {
      if (key === 'WEBHOOK_SECRET') return 'test_webhook_secret_key_123';
      return defaultVal;
    }),
  };

  beforeEach(async () => {
    vi.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FinanceService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: ConfigService, useValue: mockConfigService },
      ],
    }).compile();

    service = module.get<FinanceService>(FinanceService);

    // Configurar que $transaction ejecute el callback pasando el mismo mockPrisma
    mockPrisma.$transaction.mockImplementation(async (callback: any) => {
      return callback(mockPrisma);
    });
  });

  describe('holdFundsInEscrow', () => {
    it('debe retener fondos en Escrow registrando una entrada negativa en el Ledger inmutable', async () => {
      mockPrisma.wallet.upsert.mockResolvedValue(mockWallet);
      mockPrisma.ledgerEntry.findFirst.mockResolvedValue(null); // No previous hold
      mockPrisma.$queryRaw
        .mockResolvedValueOnce([]) // for UPDATE query
        .mockResolvedValueOnce([{ balance: 150.0 }]); // balance check: S/. 150 available

      mockPrisma.ledgerEntry.create.mockResolvedValue({
        id: 'entry-hold-1',
        amount: -75.0,
        type: 'HOLD_ESCROW',
        jobRequestId: 'job-101',
      });

      const result = await service.holdFundsInEscrow('user-client-1', 'job-101', 75.0);

      expect(result.success).toBe(true);
      expect(result.amountHeld).toBe(75.0);
      expect(result.remainingAvailableBalance).toBe(75.0);
      expect(mockPrisma.ledgerEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            amount: -75.0,
            type: 'HOLD_ESCROW',
            jobRequestId: 'job-101',
          }),
        }),
      );
    });

    it('debe rechazar con BadRequestException si el saldo disponible es insuficiente', async () => {
      mockPrisma.wallet.upsert.mockResolvedValue(mockWallet);
      mockPrisma.ledgerEntry.findFirst.mockResolvedValue(null);
      mockPrisma.$queryRaw
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([{ balance: 40.0 }]); // S/. 40 disponible < S/. 75 requerido

      await expect(
        service.holdFundsInEscrow('user-client-1', 'job-101', 75.0),
      ).rejects.toThrow(BadRequestException);
    });

    it('debe rechazar con ConflictException si ya existe una retención previa para ese jobRequestId', async () => {
      mockPrisma.wallet.upsert.mockResolvedValue(mockWallet);
      mockPrisma.ledgerEntry.findFirst.mockResolvedValue({
        id: 'existing-hold',
        jobRequestId: 'job-101',
      });

      await expect(
        service.holdFundsInEscrow('user-client-1', 'job-101', 75.0),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('releaseEscrow', () => {
    it('debe transferir fondos al técnico descontando comisión (8%) y tarifa fija (S/. 2) con invariante estricta', async () => {
      mockPrisma.wallet.upsert
        .mockResolvedValueOnce(mockWallet)
        .mockResolvedValueOnce(mockWorkerWallet)
        .mockResolvedValueOnce(mockPlatformWallet);

      mockPrisma.user.findFirst.mockResolvedValue({ id: 'platform-treasury', email: 'treasury@chamba.pe' });
      mockPrisma.$queryRaw.mockResolvedValue([]); // for update locks

      // Hold entry: totalCustody = S/. 102.00 (P = 100 + S/. 2 service fee)
      mockPrisma.ledgerEntry.findFirst
        .mockResolvedValueOnce({
          id: 'entry-hold-1',
          amount: -102.0,
          type: 'HOLD_ESCROW',
          jobRequestId: 'job-202',
        })
        .mockResolvedValueOnce(null); // not yet released

      mockPrisma.ledgerEntry.create
        .mockResolvedValueOnce({ id: 'entry-release-1', amount: 92.0, type: 'RELEASE_ESCROW' })
        .mockResolvedValueOnce({ id: 'entry-comm-1', amount: 8.0, type: 'COMMISSION' })
        .mockResolvedValueOnce({ id: 'entry-fee-1', amount: 2.0, type: 'SERVICE_FEE' });

      mockPrisma.$queryRaw.mockResolvedValueOnce([{ balance: 92.0 }]);

      const result = await service.releaseEscrow('user-client-1', 'user-worker-1', 'job-202');

      expect(result.success).toBe(true);
      expect(result.totalCustody).toBe(102.0);
      expect(result.amountReleased).toBe(92.0); // P - 8% = 100 - 8 = 92
      expect(result.commission).toBe(8.0);      // 8% de 100
      expect(result.serviceFee).toBe(2.0);      // Tarifa de servicio S/. 2

      // Invariante contable estricta: custodia = liberación + comisión + tarifa
      expect(result.totalCustody).toBe(result.amountReleased + result.commission + result.serviceFee);

      // Verificamos que se crearon los tres asientos contables
      expect(mockPrisma.ledgerEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            walletId: mockWorkerWallet.id,
            amount: 92.0,
            type: 'RELEASE_ESCROW',
            jobRequestId: 'job-202',
          }),
        }),
      );
      expect(mockPrisma.ledgerEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            walletId: mockPlatformWallet.id,
            amount: 8.0,
            type: 'COMMISSION',
            jobRequestId: 'job-202',
          }),
        }),
      );
      expect(mockPrisma.ledgerEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            walletId: mockPlatformWallet.id,
            amount: 2.0,
            type: 'SERVICE_FEE',
            jobRequestId: 'job-202',
          }),
        }),
      );
    });

    it('debe fallar si no existen fondos en Escrow para ese jobRequestId', async () => {
      mockPrisma.wallet.upsert
        .mockResolvedValueOnce(mockWallet)
        .mockResolvedValueOnce(mockWorkerWallet)
        .mockResolvedValueOnce(mockPlatformWallet);

      mockPrisma.user.findFirst.mockResolvedValue({ id: 'platform-treasury', email: 'treasury@chamba.pe' });
      mockPrisma.$queryRaw.mockResolvedValue([]);
      mockPrisma.ledgerEntry.findFirst.mockResolvedValueOnce(null);

      await expect(
        service.releaseEscrow('user-client-1', 'user-worker-1', 'job-inexistente'),
      ).rejects.toThrow(NotFoundException);
    });

    it('debe rechazar con ConflictException si los fondos ya fueron liberados previamente', async () => {
      mockPrisma.wallet.upsert
        .mockResolvedValueOnce(mockWallet)
        .mockResolvedValueOnce(mockWorkerWallet)
        .mockResolvedValueOnce(mockPlatformWallet);

      mockPrisma.user.findFirst.mockResolvedValue({ id: 'platform-treasury', email: 'treasury@chamba.pe' });
      mockPrisma.$queryRaw.mockResolvedValue([]);
      mockPrisma.ledgerEntry.findFirst
        .mockResolvedValueOnce({ id: 'entry-hold-1', amount: -102.0, type: 'HOLD_ESCROW' })
        .mockResolvedValueOnce({ id: 'entry-release-prev', type: 'RELEASE_ESCROW' });

      await expect(
        service.releaseEscrow('user-client-1', 'user-worker-1', 'job-202'),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('refundEscrow', () => {
    it('debe reembolsar el 100% al cliente si el técnico NO estaba en camino', async () => {
      mockPrisma.wallet.upsert.mockResolvedValue(mockWallet);
      mockPrisma.$queryRaw.mockResolvedValue([]);
      mockPrisma.ledgerEntry.findFirst
        .mockResolvedValueOnce({ id: 'entry-hold-1', amount: -102.0, type: 'HOLD_ESCROW' })
        .mockResolvedValueOnce(null); // not released/refunded

      mockPrisma.ledgerEntry.create.mockResolvedValueOnce({
        id: 'entry-refund-1',
        amount: 102.0,
        type: 'REFUND_ESCROW',
      });

      const result = await service.refundEscrow('user-client-1', 'job-303', false);

      expect(result.success).toBe(true);
      expect(result.totalCustody).toBe(102.0);
      expect(result.refundAmount).toBe(102.0);
      expect(result.compensation).toBe(0);
      expect(mockPrisma.ledgerEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            walletId: mockWallet.id,
            amount: 102.0,
            type: 'REFUND_ESCROW',
            jobRequestId: 'job-303',
          }),
        }),
      );
    });

    it('debe liquidar 10% de compensación al técnico si ya estaba EN_CAMINO y reembolsar el remanente al cliente', async () => {
      mockPrisma.wallet.upsert
        .mockResolvedValueOnce(mockWallet)
        .mockResolvedValueOnce(mockWorkerWallet);

      mockPrisma.$queryRaw.mockResolvedValue([]);
      // Custodia S/. 102 (P = 100). 10% de 100 = S/. 10.00 compensación
      mockPrisma.ledgerEntry.findFirst
        .mockResolvedValueOnce({ id: 'entry-hold-1', amount: -102.0, type: 'HOLD_ESCROW' })
        .mockResolvedValueOnce(null);

      mockPrisma.ledgerEntry.create
        .mockResolvedValueOnce({ id: 'entry-comp-1', amount: 10.0, type: 'COMPENSATION' })
        .mockResolvedValueOnce({ id: 'entry-ref-1', amount: 92.0, type: 'REFUND_ESCROW' });

      const result = await service.refundEscrow('user-client-1', 'job-303', true, 'user-worker-1');

      expect(result.success).toBe(true);
      expect(result.totalCustody).toBe(102.0);
      expect(result.compensation).toBe(10.0);
      expect(result.refundAmount).toBe(92.0);

      // Invariante contable estricta: custodia = compensación + reembolso
      expect(result.totalCustody).toBe(result.compensation + result.refundAmount);

      expect(mockPrisma.ledgerEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            walletId: mockWorkerWallet.id,
            amount: 10.0,
            type: 'COMPENSATION',
            jobRequestId: 'job-303',
          }),
        }),
      );
      expect(mockPrisma.ledgerEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            walletId: mockWallet.id,
            amount: 92.0,
            type: 'REFUND_ESCROW',
            jobRequestId: 'job-303',
          }),
        }),
      );
    });

    it('debe aplicar límites de compensación mínima (S/. 5) y máxima (S/. 20)', async () => {
      mockPrisma.wallet.upsert
        .mockResolvedValueOnce(mockWallet)
        .mockResolvedValueOnce(mockWorkerWallet);

      mockPrisma.$queryRaw.mockResolvedValue([]);

      // Caso A: Trabajo de S/. 30 (10% = 3) -> debe aplicar mínimo S/. 5
      mockPrisma.ledgerEntry.findFirst
        .mockResolvedValueOnce({ id: 'entry-hold-low', amount: -32.0, type: 'HOLD_ESCROW' })
        .mockResolvedValueOnce(null);

      mockPrisma.ledgerEntry.create
        .mockResolvedValueOnce({ id: 'entry-comp-low', amount: 5.0, type: 'COMPENSATION' })
        .mockResolvedValueOnce({ id: 'entry-ref-low', amount: 27.0, type: 'REFUND_ESCROW' });

      const resultLow = await service.refundEscrow('user-client-1', 'job-low', true, 'user-worker-1');
      expect(resultLow.compensation).toBe(5.0);
      expect(resultLow.refundAmount).toBe(27.0);
      expect(resultLow.totalCustody).toBe(resultLow.compensation + resultLow.refundAmount);

      // Caso B: Trabajo de S/. 300 (10% = 30) -> debe topar al máximo S/. 20
      mockPrisma.ledgerEntry.findFirst
        .mockResolvedValueOnce({ id: 'entry-hold-high', amount: -302.0, type: 'HOLD_ESCROW' })
        .mockResolvedValueOnce(null);

      mockPrisma.ledgerEntry.create
        .mockResolvedValueOnce({ id: 'entry-comp-high', amount: 20.0, type: 'COMPENSATION' })
        .mockResolvedValueOnce({ id: 'entry-ref-high', amount: 282.0, type: 'REFUND_ESCROW' });

      const resultHigh = await service.refundEscrow('user-client-1', 'job-high', true, 'user-worker-1');
      expect(resultHigh.compensation).toBe(20.0);
      expect(resultHigh.refundAmount).toBe(282.0);
      expect(resultHigh.totalCustody).toBe(resultHigh.compensation + resultHigh.refundAmount);
    });
  });

  describe('resolveDisputeEscrow (§5, §8 L13 Regla Contable de Tarifa)', () => {
    it('debe reembolsar el 100% de la custodia (incluyendo tarifa S/ 2) al cliente si el veredicto es REFUND_CLIENT', async () => {
      mockPrisma.wallet.upsert.mockResolvedValue(mockWallet);
      mockPrisma.$queryRaw.mockResolvedValue([]);
      mockPrisma.ledgerEntry.findFirst
        .mockResolvedValueOnce({ id: 'entry-hold-1', amount: -52.0, type: 'HOLD_ESCROW' })
        .mockResolvedValueOnce(null);

      mockPrisma.ledgerEntry.create.mockResolvedValueOnce({
        id: 'entry-ref-disp',
        amount: 52.0,
        type: 'REFUND_ESCROW',
      });

      const result = await service.resolveDisputeEscrow('user-client-1', 'user-worker-1', 'job-disp-1', 'REFUND_CLIENT');

      expect(result.success).toBe(true);
      expect(result.totalCustody).toBe(52.0);
      expect(result.refundClient).toBe(52.0);
      expect(result.amountToWorker).toBe(0);
      expect(result.commission).toBe(0);
      expect(result.serviceFee).toBe(0);
      expect(result.refundClient + result.amountToWorker + result.commission + result.serviceFee).toBe(result.totalCustody);
    });

    it('debe retener tarifa S/ 2 y comisión 8% para la plataforma y liberar 92% al técnico si el veredicto es RELEASE_WORKER', async () => {
      mockPrisma.wallet.upsert
        .mockResolvedValueOnce(mockWallet)
        .mockResolvedValueOnce(mockWorkerWallet)
        .mockResolvedValueOnce(mockPlatformWallet);

      mockPrisma.user.findFirst.mockResolvedValue({ id: 'platform-treasury', email: 'treasury@chamba.pe' });
      mockPrisma.$queryRaw.mockResolvedValue([]);
      mockPrisma.ledgerEntry.findFirst
        .mockResolvedValueOnce({ id: 'entry-hold-1', amount: -52.0, type: 'HOLD_ESCROW' })
        .mockResolvedValueOnce(null);

      mockPrisma.ledgerEntry.create
        .mockResolvedValueOnce({ id: 'entry-worker', amount: 46.0, type: 'RELEASE_ESCROW' })
        .mockResolvedValueOnce({ id: 'entry-comm', amount: 4.0, type: 'COMMISSION' })
        .mockResolvedValueOnce({ id: 'entry-fee', amount: 2.0, type: 'SERVICE_FEE' });

      const result = await service.resolveDisputeEscrow('user-client-1', 'user-worker-1', 'job-disp-2', 'RELEASE_WORKER');

      expect(result.success).toBe(true);
      expect(result.totalCustody).toBe(52.0);
      expect(result.refundClient).toBe(0);
      expect(result.amountToWorker).toBe(46.0); // 50 * 0.92 = 46.00
      expect(result.commission).toBe(4.0); // 50 * 0.08 = 4.00
      expect(result.serviceFee).toBe(2.0); // Plataforma retiene tarifa
      expect(result.refundClient + result.amountToWorker + result.commission + result.serviceFee).toBe(result.totalCustody);
    });

    it('debe retener tarifa S/ 2 para la plataforma y dividir el remanente P al 50% con 8% de comisión si el veredicto es SPLIT', async () => {
      mockPrisma.wallet.upsert
        .mockResolvedValueOnce(mockWallet)
        .mockResolvedValueOnce(mockWorkerWallet)
        .mockResolvedValueOnce(mockPlatformWallet);

      mockPrisma.user.findFirst.mockResolvedValue({ id: 'platform-treasury', email: 'treasury@chamba.pe' });
      mockPrisma.$queryRaw.mockResolvedValue([]);
      mockPrisma.ledgerEntry.findFirst
        .mockResolvedValueOnce({ id: 'entry-hold-1', amount: -52.0, type: 'HOLD_ESCROW' })
        .mockResolvedValueOnce(null);

      mockPrisma.ledgerEntry.create
        .mockResolvedValueOnce({ id: 'entry-ref-split', amount: 25.0, type: 'REFUND_ESCROW' })
        .mockResolvedValueOnce({ id: 'entry-rel-split', amount: 23.0, type: 'RELEASE_ESCROW' })
        .mockResolvedValueOnce({ id: 'entry-com-split', amount: 2.0, type: 'COMMISSION' })
        .mockResolvedValueOnce({ id: 'entry-fee-split', amount: 2.0, type: 'SERVICE_FEE' });

      const result = await service.resolveDisputeEscrow('user-client-1', 'user-worker-1', 'job-disp-3', 'SPLIT', 50);

      expect(result.success).toBe(true);
      expect(result.totalCustody).toBe(52.0);
      expect(result.refundClient).toBe(25.0); // 50% de S/ 50
      expect(result.amountToWorker).toBe(23.0); // 50% de S/ 50 (25) - 8% com (2) = 23
      expect(result.commission).toBe(2.0); // 8% de 25 = 2.00
      expect(result.serviceFee).toBe(2.0); // Plataforma retiene tarifa
      expect(result.refundClient + result.amountToWorker + result.commission + result.serviceFee).toBe(result.totalCustody);
    });
  });

  describe('Auditoría Financiera y Control de Acceso (getWalletsOverviewForJob)', () => {
    const mockJob = {
      id: 'job-audit-1',
      clientId: 'client-1',
      workerId: 'worker-prof-1',
      worker: { userId: 'worker-user-1' },
      budget: 100,
    };

    it('debe rechazar con 403 Forbidden si un tercero ajeno consulta la auditoría', async () => {
      mockPrisma.jobRequest.findUnique.mockResolvedValue(mockJob);

      await expect(
        service.getWalletsOverviewForJob('job-audit-1', { id: 'stranger-user', role: 'CLIENT' })
      ).rejects.toThrow(ForbiddenException);
    });

    it('debe permitir al cliente ver su propio saldo pero ocultar el saldo del trabajador y plataforma', async () => {
      mockPrisma.jobRequest.findUnique.mockResolvedValue(mockJob);
      mockPrisma.$queryRaw
        .mockResolvedValueOnce([{ balance: 250.0 }])
        .mockResolvedValueOnce([]);
      mockPrisma.ledgerEntry.findMany.mockResolvedValue([
        { type: 'HOLD_ESCROW', amount: -102.0 },
        { type: 'RELEASE_ESCROW', amount: 92.0 },
        { type: 'COMMISSION', amount: 8.0 },
        { type: 'SERVICE_FEE', amount: 2.0 },
      ]);

      const result = await service.getWalletsOverviewForJob('job-audit-1', { id: 'client-1', role: 'CLIENT' });

      expect(result.jobId).toBe('job-audit-1');
      expect(result.clientWallet).toBeDefined();
      expect(result.workerWallet).toBeNull();
      expect(result.platformWallet).toBeNull();
      expect(result.audit.invariantPassed).toBe(true);
    });

    it('debe permitir al trabajador ver su propio saldo pero ocultar el saldo del cliente y plataforma', async () => {
      mockPrisma.jobRequest.findUnique.mockResolvedValue(mockJob);
      mockPrisma.$queryRaw
        .mockResolvedValueOnce([{ balance: 180.0 }])
        .mockResolvedValueOnce([]);
      mockPrisma.ledgerEntry.findMany.mockResolvedValue([
        { type: 'HOLD_ESCROW', amount: -102.0 },
        { type: 'RELEASE_ESCROW', amount: 92.0 },
        { type: 'COMMISSION', amount: 8.0 },
        { type: 'SERVICE_FEE', amount: 2.0 },
      ]);

      const result = await service.getWalletsOverviewForJob('job-audit-1', { id: 'worker-user-1', role: 'WORKER' });

      expect(result.jobId).toBe('job-audit-1');
      expect(result.clientWallet).toBeNull();
      expect(result.workerWallet).toBeDefined();
      expect(result.platformWallet).toBeNull();
      expect(result.audit.invariantPassed).toBe(true);
    });

    it('debe permitir a un usuario con rol SUPPORT ver todos los saldos (cliente, trabajador y tesorería)', async () => {
      mockPrisma.jobRequest.findUnique.mockResolvedValue(mockJob);
      mockPrisma.wallet.upsert.mockResolvedValue({ id: 'wallet-any', userId: 'any' });
      mockPrisma.user.findFirst.mockResolvedValue({ id: 'platform-user' });
      mockPrisma.$queryRaw.mockResolvedValue([{ balance: 500.0 }]);
      mockPrisma.ledgerEntry.findMany.mockResolvedValue([
        { type: 'HOLD_ESCROW', amount: -102.0 },
        { type: 'RELEASE_ESCROW', amount: 92.0 },
        { type: 'COMMISSION', amount: 8.0 },
        { type: 'SERVICE_FEE', amount: 2.0 },
      ]);

      const result = await service.getWalletsOverviewForJob('job-audit-1', { id: 'support-agent-1', role: 'SUPPORT' });

      expect(result.jobId).toBe('job-audit-1');
      expect(result.clientWallet).toBeDefined();
      expect(result.workerWallet).toBeDefined();
      expect(result.platformWallet).toBeDefined();
      expect(result.audit.invariantPassed).toBe(true);
    });
  });

  describe('Verificación de Firmas HMAC en Webhooks', () => {
    it('debe validar exitosamente una firma HMAC-SHA256 correcta', () => {
      const payload = JSON.stringify({ event: 'payment.succeeded', amount: 100 });
      const secret = 'test_webhook_secret_key_123';
      const validSignature = crypto.createHmac('sha256', secret).update(payload).digest('hex');

      const isValid = service.verifyWebhookSignature(payload, validSignature);
      expect(isValid).toBe(true);
    });

    it('debe rechazar firmas alteradas o falsificadas', () => {
      const payload = JSON.stringify({ event: 'payment.succeeded', amount: 100 });
      const alteredPayload = JSON.stringify({ event: 'payment.succeeded', amount: 10000 });
      const secret = 'test_webhook_secret_key_123';
      const signature = crypto.createHmac('sha256', secret).update(payload).digest('hex');

      const isValid = service.verifyWebhookSignature(alteredPayload, signature);
      expect(isValid).toBe(false);
    });
  });
});
