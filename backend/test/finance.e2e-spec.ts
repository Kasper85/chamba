import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import * as crypto from 'crypto';
import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/prisma/prisma.service.js';
import { JwtAuthGuard } from '../src/auth/guards/jwt-auth.guard.js';

describe('CHAMBA FinTech & Escrow Flow (e2e)', () => {
  let app: INestApplication;

  const testSecret = 'chamba_culqi_webhook_secret_key_2026';
  const clientUser = { id: 'client-lucia-1', email: 'lucia@chamba.pe', fullName: 'Lucía Fernández' };
  const workerUser = { id: 'worker-jorge-1', email: 'jorge@chamba.pe', fullName: 'Jorge Quispe' };

  // Store contable en memoria que implementa exclusión mutua (Row-level Lock: SELECT ... FOR UPDATE)
  const clientWalletId = 'wallet-client-lucia';
  const workerWalletId = 'wallet-worker-jorge';

  let ledgerEntries: Array<{
    id: string;
    walletId: string;
    amount: number;
    type: string;
    jobRequestId?: string | null;
    description?: string | null;
    createdAt: Date;
  }> = [];

  // Mutex para simular SELECT ... FOR UPDATE sobre billeteras
  let isWalletLocked = false;
  const lockQueue: Array<() => void> = [];

  const acquireWalletLock = async () => {
    if (isWalletLocked) {
      await new Promise<void>((resolve) => lockQueue.push(resolve));
    }
    isWalletLocked = true;
  };

  const releaseWalletLock = () => {
    isWalletLocked = false;
    const next = lockQueue.shift();
    if (next) next();
  };

  const calculateBalance = (wId: string) => {
    return ledgerEntries
      .filter((e) => e.walletId === wId)
      .reduce((acc, curr) => acc + curr.amount, 0);
  };

  const mockPrisma = {
    $connect: vi.fn(),
    $disconnect: vi.fn(),
    wallet: {
      upsert: vi.fn().mockImplementation(({ where }) => {
        if (where.userId === clientUser.id) {
          return Promise.resolve({ id: clientWalletId, userId: clientUser.id });
        }
        return Promise.resolve({ id: workerWalletId, userId: workerUser.id });
      }),
    },
    ledgerEntry: {
      findFirst: vi.fn().mockImplementation(({ where }) => {
        const found = ledgerEntries.find((e) => {
          if (where.jobRequestId && e.jobRequestId !== where.jobRequestId) return false;
          if (where.type && e.type !== where.type) return false;
          if (where.walletId && e.walletId !== where.walletId) return false;
          return true;
        });
        return Promise.resolve(found || null);
      }),
      create: vi.fn().mockImplementation(({ data }) => {
        const entry = {
          id: `entry-${Date.now()}-${Math.random()}`,
          walletId: data.walletId,
          amount: Number(data.amount),
          type: data.type,
          jobRequestId: data.jobRequestId || null,
          description: data.description || null,
          createdAt: new Date(),
        };
        ledgerEntries.push(entry);
        return Promise.resolve(entry);
      }),
      findMany: vi.fn().mockImplementation(({ where }) => {
        return Promise.resolve(ledgerEntries.filter((e) => e.walletId === where.walletId));
      }),
    },
    $queryRaw: vi.fn().mockImplementation(async (query: any) => {
      const qStr = typeof query === 'string' ? query : JSON.stringify(query);
      if (qStr.toLowerCase().includes('sum(amount)')) {
        const isWorker = qStr.includes(workerWalletId);
        const wId = isWorker ? workerWalletId : clientWalletId;
        return [{ balance: calculateBalance(wId) }];
      }
      return [];
    }),
    $transaction: vi.fn().mockImplementation(async (callback: any) => {
      await acquireWalletLock();
      try {
        // Simular pequeño retardo de procesamiento en base de datos para amplificar condiciones de carrera concurrentes
        await new Promise((r) => setTimeout(r, 25));
        return await callback(mockPrisma);
      } finally {
        releaseWalletLock();
      }
    }),
  };

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(mockPrisma)
      .overrideGuard(JwtAuthGuard)
      .useValue({
        canActivate: (context: any) => {
          const req = context.switchToHttp().getRequest();
          const authHeader = req.headers['authorization'];
          if (authHeader && authHeader.includes('worker')) {
            req.user = workerUser;
          } else {
            req.user = clientUser;
          }
          return true;
        },
      })
      .compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    // Reset ledger entries before each scenario
    ledgerEntries = [];
  });

  describe('1. Verificación de Webhooks de Pasarela con Firma HMAC', () => {
    it('POST /api/v1/webhooks/payment — debe rechazar firmas HMAC inválidas con 401', async () => {
      const payload = {
        event: 'payment.succeeded',
        data: {
          transactionId: 'tx_fake_999',
          userId: clientUser.id,
          amount: 100.0,
        },
      };

      await request(app.getHttpServer())
        .post('/api/v1/webhooks/payment')
        .set('x-webhook-signature', 'firma_totalmente_falsa_123')
        .send(payload)
        .expect(401);
    });

    it('POST /api/v1/webhooks/payment — debe acreditar depósito con firma HMAC válida', async () => {
      const payload = {
        event: 'payment.succeeded',
        data: {
          transactionId: 'tx_valid_001',
          userId: clientUser.id,
          amount: 100.0,
        },
      };

      const rawJson = JSON.stringify(payload);
      const signature = crypto.createHmac('sha256', testSecret).update(rawJson).digest('hex');

      const response = await request(app.getHttpServer())
        .post('/api/v1/webhooks/payment')
        .set('x-webhook-signature', signature)
        .send(payload)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.deposit.amount).toBe(100.0);
      expect(calculateBalance(clientWalletId)).toBe(100.0);
    });
  });

  describe('2. Ciclo de Vida Escrow (Hold y Release)', () => {
    it('debe retener fondos y luego liberarlos al técnico tras confirmación de servicio', async () => {
      // Acreditar saldo inicial de S/. 120 al cliente
      ledgerEntries.push({
        id: 'init-deposit',
        walletId: clientWalletId,
        amount: 120.0,
        type: 'DEPOSIT',
        createdAt: new Date(),
      });

      // 1. Cliente retiene S/. 70 para la solicitud #job-101
      const holdRes = await request(app.getHttpServer())
        .post('/api/v1/finance/escrow/hold')
        .set('Authorization', 'Bearer client_token')
        .send({
          jobRequestId: 'job-101',
          amount: 70.0,
          description: 'Garantía gasfitería #job-101',
        })
        .expect(201);

      expect(holdRes.body.success).toBe(true);
      expect(holdRes.body.amountHeld).toBe(70.0);
      expect(calculateBalance(clientWalletId)).toBe(50.0); // 120 - 70 = 50 disponibles

      // 2. Cliente confirma el trabajo y libera los fondos al técnico
      const releaseRes = await request(app.getHttpServer())
        .post('/api/v1/finance/escrow/release')
        .set('Authorization', 'Bearer client_token')
        .send({
          jobRequestId: 'job-101',
          workerUserId: workerUser.id,
        })
        .expect(200);

      expect(releaseRes.body.success).toBe(true);
      expect(releaseRes.body.amountReleased).toBe(70.0);
      expect(calculateBalance(workerWalletId)).toBe(70.0); // El técnico tiene S/. 70 disponibles
    });
  });

  describe('3. Simulación de Condiciones de Carrera (Race Conditions) en Pagos Concurrentes', () => {
    it('debe prevenir doble gasto (double-spending): ante 2 retenciones simultáneas que exceden el saldo, solo 1 debe tener éxito y la otra debe fallar con 400', async () => {
      // El cliente tiene exactamente S/. 100 de saldo disponible
      ledgerEntries.push({
        id: 'race-deposit',
        walletId: clientWalletId,
        amount: 100.0,
        type: 'DEPOSIT',
        createdAt: new Date(),
      });

      // Dos solicitudes concurrentes intentan retener S/. 80 cada una (Total = S/. 160 > S/. 100 saldo disponible)
      const req1 = request(app.getHttpServer())
        .post('/api/v1/finance/escrow/hold')
        .set('Authorization', 'Bearer client_token')
        .send({
          jobRequestId: 'job-concurrent-A',
          amount: 80.0,
        });

      const req2 = request(app.getHttpServer())
        .post('/api/v1/finance/escrow/hold')
        .set('Authorization', 'Bearer client_token')
        .send({
          jobRequestId: 'job-concurrent-B',
          amount: 80.0,
        });

      // Disparar ambas peticiones exactamente al mismo tiempo
      const [res1, res2] = await Promise.all([req1, req2]);

      const statuses = [res1.status, res2.status];

      // Uno debe haber tenido éxito (201 Created) y el otro debe ser rechazado por saldo insuficiente (400 Bad Request)
      expect(statuses).toContain(201);
      expect(statuses).toContain(400);

      // El saldo final jamás debe ser negativo (-60); debe ser exactamente S/. 20 (100 - 80)
      const finalBalance = calculateBalance(clientWalletId);
      expect(finalBalance).toBe(20.0);
    });
  });
});
