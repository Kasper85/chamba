import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import { PaymentWebhookDto } from './dto/payment-webhook.dto.js';

export interface WalletSummary {
  walletId: string;
  userId: string;
  availableBalance: number;
  inEscrowBalance: number;
  totalBalance: number;
  currency: string;
  recentTransactions: Array<{
    id: string;
    amount: number;
    type: string;
    jobRequestId: string | null;
    description: string | null;
    createdAt: Date;
  }>;
}

@Injectable()
export class FinanceService {
  private readonly logger = new Logger(FinanceService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
  ) {}

  /**
   * Obtiene o inicializa la billetera contable asociada al usuario.
   */
  async getOrCreateWallet(
    userId: string,
    tx?: Prisma.TransactionClient,
  ) {
    const client = tx || this.prisma;
    return client.wallet.upsert({
      where: { userId },
      create: { userId },
      update: {},
    });
  }

  /**
   * Retiene fondos en custodia (Escrow) cuando el cliente acepta una oferta.
   * Utiliza transacciones ACID con aislamiento SERIALIZABLE y bloqueo FOR UPDATE
   * para prevenir condiciones de carrera en pagos concurrentes.
   */
  async holdFundsInEscrow(
    clientId: string,
    jobRequestId: string,
    amount: number,
    description?: string,
  ) {
    if (amount <= 0) {
      throw new BadRequestException('El monto a retener en Escrow debe ser mayor a S/. 0.00');
    }

    return this.prisma.$transaction(
      async (tx) => {
        // 1. Obtener o crear billetera del cliente
        const wallet = await this.getOrCreateWallet(clientId, tx);

        // 2. Bloquear la fila de la billetera (SELECT ... FOR UPDATE) para evitar concurrencia
        await tx.$queryRaw`SELECT id FROM "wallets" WHERE id = ${wallet.id} FOR UPDATE`;

        // 3. Validar si ya existe una retención activa para este jobRequestId
        const existingHold = await tx.ledgerEntry.findFirst({
          where: {
            walletId: wallet.id,
            jobRequestId,
            type: 'HOLD_ESCROW',
          },
        });

        if (existingHold) {
          throw new ConflictException(
            `Ya existe una retención activa en Escrow para la solicitud ${jobRequestId}`,
          );
        }

        // 4. Calcular el saldo disponible actual sumando todas las entradas inmutables del libro mayor
        const balanceResult = await tx.$queryRaw<{ balance: number }[]>`
          SELECT COALESCE(SUM(amount), 0)::float AS balance
          FROM "ledger_entries"
          WHERE wallet_id = ${wallet.id}
        `;
        const currentAvailableBalance = balanceResult[0]?.balance ?? 0;

        if (currentAvailableBalance < amount) {
          throw new BadRequestException(
            `Saldo insuficiente para retener fondos en Escrow. Saldo disponible: S/. ${currentAvailableBalance.toFixed(2)}, requerido: S/. ${amount.toFixed(2)}`,
          );
        }

        // 5. Registrar entrada inmutable negativa en el Libro Mayor (Ledger)
        const ledgerEntry = await tx.ledgerEntry.create({
          data: {
            walletId: wallet.id,
            amount: -amount,
            type: 'HOLD_ESCROW',
            jobRequestId,
            description:
              description ||
              `Fondos retenidos en Escrow (garantía de pago) para solicitud #${jobRequestId}`,
          },
        });

        const newAvailableBalance = currentAvailableBalance - amount;

        this.logger.log(
          `🔒 Escrow retenido: S/. ${amount.toFixed(2)} en billetera ${wallet.id} para job #${jobRequestId}`,
        );

        return {
          success: true,
          message: 'Fondos retenidos exitosamente en custodia segura (Escrow)',
          ledgerEntryId: ledgerEntry.id,
          jobRequestId,
          amountHeld: amount,
          remainingAvailableBalance: newAvailableBalance,
        };
      },
      {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      },
    );
  }

  /**
   * Libera los fondos retenidos en Escrow al técnico cuando el cliente confirma
   * la culminación satisfactoria del trabajo (Fase 4 de la app).
   */
  async releaseEscrow(
    clientId: string,
    workerUserId: string,
    jobRequestId: string,
    releaseAmount?: number,
  ) {
    return this.prisma.$transaction(
      async (tx) => {
        // 1. Obtener billeteras de cliente y técnico
        const clientWallet = await this.getOrCreateWallet(clientId, tx);
        const workerWallet = await this.getOrCreateWallet(workerUserId, tx);

        // 2. Bloqueo determinístico de ambas billeteras para evitar interbloqueos (deadlocks)
        const sortedIds = [clientWallet.id, workerWallet.id].sort();
        for (const wId of sortedIds) {
          await tx.$queryRaw`SELECT id FROM "wallets" WHERE id = ${wId} FOR UPDATE`;
        }

        // 3. Verificar que existan fondos retenidos para este jobRequestId
        const holdEntry = await tx.ledgerEntry.findFirst({
          where: {
            walletId: clientWallet.id,
            jobRequestId,
            type: 'HOLD_ESCROW',
          },
        });

        if (!holdEntry) {
          throw new NotFoundException(
            `No se encontraron fondos retenidos en Escrow para la solicitud #${jobRequestId}`,
          );
        }

        // 4. Verificar que no se hayan liberado previamente
        const alreadyReleased = await tx.ledgerEntry.findFirst({
          where: {
            jobRequestId,
            type: 'RELEASE_ESCROW',
          },
        });

        if (alreadyReleased) {
          throw new ConflictException(
            `Los fondos de la solicitud #${jobRequestId} ya fueron liberados al técnico previamente`,
          );
        }

        const amountToCredit = releaseAmount ?? Math.abs(Number(holdEntry.amount));

        // 5. Registrar entrada inmutable positiva en la billetera del técnico
        const releaseEntry = await tx.ledgerEntry.create({
          data: {
            walletId: workerWallet.id,
            amount: amountToCredit,
            type: 'RELEASE_ESCROW',
            jobRequestId,
            description: `Liberación de pago por trabajo completado #${jobRequestId}`,
          },
        });

        // 6. Calcular el nuevo saldo total disponible del técnico
        const workerBalanceResult = await tx.$queryRaw<{ balance: number }[]>`
          SELECT COALESCE(SUM(amount), 0)::float AS balance
          FROM "ledger_entries"
          WHERE wallet_id = ${workerWallet.id}
        `;
        const workerAvailableBalance = workerBalanceResult[0]?.balance ?? 0;

        this.logger.log(
          `🔓 Escrow liberado: S/. ${amountToCredit.toFixed(2)} transferidos al técnico ${workerUserId} por job #${jobRequestId}`,
        );

        return {
          success: true,
          message: 'Fondos liberados exitosamente al técnico por trabajo concluido',
          releaseEntryId: releaseEntry.id,
          jobRequestId,
          amountReleased: amountToCredit,
          workerUserId,
          workerNewAvailableBalance: workerAvailableBalance,
        };
      },
      {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      },
    );
  }

  /**
   * Recarga saldo (depósito) en la billetera de un usuario.
   */
  async depositFunds(
    userId: string,
    amount: number,
    description?: string,
    jobRequestId?: string,
  ) {
    if (amount <= 0) {
      throw new BadRequestException('El monto a depositar debe ser mayor a S/. 0.00');
    }

    return this.prisma.$transaction(
      async (tx) => {
        const wallet = await this.getOrCreateWallet(userId, tx);
        await tx.$queryRaw`SELECT id FROM "wallets" WHERE id = ${wallet.id} FOR UPDATE`;

        const entry = await tx.ledgerEntry.create({
          data: {
            walletId: wallet.id,
            amount,
            type: 'DEPOSIT',
            jobRequestId: jobRequestId || null,
            description: description || 'Recarga de saldo en billetera CHAMBA',
          },
        });

        const balanceResult = await tx.$queryRaw<{ balance: number }[]>`
          SELECT COALESCE(SUM(amount), 0)::float AS balance
          FROM "ledger_entries"
          WHERE wallet_id = ${wallet.id}
        `;
        const newBalance = balanceResult[0]?.balance ?? 0;

        return {
          success: true,
          message: 'Depósito acreditado exitosamente en el Libro Mayor',
          ledgerEntryId: entry.id,
          amount,
          newBalance,
        };
      },
      {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      },
    );
  }

  /**
   * Consulta el balance contable y movimientos recientes de un usuario.
   * El saldo se calcula dinámicamente sumando las entradas inmutables del Ledger.
   */
  async getWalletSummary(userId: string): Promise<WalletSummary> {
    const wallet = await this.getOrCreateWallet(userId);

    const balanceResult = await this.prisma.$queryRaw<{ balance: number }[]>`
      SELECT COALESCE(SUM(amount), 0)::float AS balance
      FROM "ledger_entries"
      WHERE wallet_id = ${wallet.id}
    `;
    const availableBalance = balanceResult[0]?.balance ?? 0;

    // Fondos actualmente retenidos en Escrow (trabajos aún no liberados ni reembolsados)
    const escrowResult = await this.prisma.$queryRaw<{ escrow: number }[]>`
      SELECT COALESCE(ABS(SUM(le.amount)), 0)::float AS escrow
      FROM "ledger_entries" le
      WHERE le.wallet_id = ${wallet.id}
        AND le.type = 'HOLD_ESCROW'
        AND le.job_request_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM "ledger_entries" r
          WHERE r.job_request_id = le.job_request_id
            AND r.type IN ('RELEASE_ESCROW', 'REFUND_ESCROW')
        )
    `;
    const inEscrowBalance = escrowResult[0]?.escrow ?? 0;

    const recentEntries = await this.prisma.ledgerEntry.findMany({
      where: { walletId: wallet.id },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    return {
      walletId: wallet.id,
      userId,
      availableBalance: Math.max(0, availableBalance),
      inEscrowBalance,
      totalBalance: Math.max(0, availableBalance) + inEscrowBalance,
      currency: 'PEN',
      recentTransactions: recentEntries.map((e) => ({
        id: e.id,
        amount: Number(e.amount),
        type: e.type,
        jobRequestId: e.jobRequestId,
        description: e.description,
        createdAt: e.createdAt,
      })),
    };
  }

  /**
   * Verifica la firma criptográfica HMAC-SHA256 de los webhooks de pagos (ej. Culqi, Niubiz, Stripe).
   */
  verifyWebhookSignature(rawBody: string | Buffer, signatureHeader?: string): boolean {
    if (!signatureHeader) {
      return false;
    }

    const secret = this.configService.get<string>(
      'WEBHOOK_SECRET',
      'chamba_culqi_webhook_secret_key_2026',
    );

    const computedSignature = crypto
      .createHmac('sha256', secret)
      .update(rawBody)
      .digest('hex');

    try {
      const signatureBuffer = Buffer.from(signatureHeader, 'hex');
      const computedBuffer = Buffer.from(computedSignature, 'hex');

      if (signatureBuffer.length !== computedBuffer.length) {
        return false;
      }

      return crypto.timingSafeEqual(signatureBuffer, computedBuffer);
    } catch {
      return false;
    }
  }

  /**
   * Procesa el webhook verificado de la pasarela de pagos.
   */
  async processPaymentWebhook(dto: PaymentWebhookDto, rawPayload: string, signature?: string) {
    const isValid = this.verifyWebhookSignature(rawPayload, signature);
    if (!isValid) {
      throw new UnauthorizedException('Firma HMAC de webhook inválida o ausente');
    }

    if (dto.event === 'payment.succeeded') {
      const { userId, amount, jobRequestId, autoHoldEscrow, transactionId } = dto.data;

      // 1. Acreditar saldo a la billetera del cliente
      const depositResult = await this.depositFunds(
        userId,
        amount,
        `Recarga confirmada por pasarela de pago (Tx #${transactionId})`,
        jobRequestId,
      );

      // 2. Si el webhook solicita retención automática en Escrow para la solicitud
      if (autoHoldEscrow && jobRequestId) {
        const holdResult = await this.holdFundsInEscrow(
          userId,
          jobRequestId,
          amount,
          `Custodia Escrow automática desde pago pasarela #${transactionId}`,
        );

        return {
          success: true,
          processedEvent: dto.event,
          transactionId,
          deposit: depositResult,
          escrowHold: holdResult,
        };
      }

      return {
        success: true,
        processedEvent: dto.event,
        transactionId,
        deposit: depositResult,
      };
    }

    return {
      success: true,
      processedEvent: dto.event,
      message: 'Evento de webhook recibido sin acciones requeridas',
    };
  }
}
