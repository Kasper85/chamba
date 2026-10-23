import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
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

  const mockPrisma = {
    wallet: {
      upsert: vi.fn(),
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
    it('debe transferir los fondos retenidos al técnico acreditando entrada positiva en su Ledger', async () => {
      mockPrisma.wallet.upsert
        .mockResolvedValueOnce(mockWallet)
        .mockResolvedValueOnce(mockWorkerWallet);

      mockPrisma.$queryRaw.mockResolvedValue([]); // for update locks

      // Hold entry exists
      mockPrisma.ledgerEntry.findFirst
        .mockResolvedValueOnce({
          id: 'entry-hold-1',
          amount: -80.0,
          type: 'HOLD_ESCROW',
          jobRequestId: 'job-202',
        })
        .mockResolvedValueOnce(null); // not yet released

      mockPrisma.ledgerEntry.create.mockResolvedValue({
        id: 'entry-release-1',
        amount: 80.0,
        type: 'RELEASE_ESCROW',
      });

      mockPrisma.$queryRaw.mockResolvedValueOnce([{ balance: 80.0 }]);

      const result = await service.releaseEscrow('user-client-1', 'user-worker-1', 'job-202');

      expect(result.success).toBe(true);
      expect(result.amountReleased).toBe(80.0);
      expect(mockPrisma.ledgerEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            walletId: mockWorkerWallet.id,
            amount: 80.0,
            type: 'RELEASE_ESCROW',
            jobRequestId: 'job-202',
          }),
        }),
      );
    });

    it('debe fallar si no existen fondos en Escrow para ese jobRequestId', async () => {
      mockPrisma.wallet.upsert
        .mockResolvedValueOnce(mockWallet)
        .mockResolvedValueOnce(mockWorkerWallet);

      mockPrisma.$queryRaw.mockResolvedValue([]);
      mockPrisma.ledgerEntry.findFirst.mockResolvedValueOnce(null);

      await expect(
        service.releaseEscrow('user-client-1', 'user-worker-1', 'job-inexistente'),
      ).rejects.toThrow(NotFoundException);
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
