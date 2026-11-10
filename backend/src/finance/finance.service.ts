import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
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
   * Obtiene o inicializa la billetera institucional de la plataforma (tesorería)
   * para registrar comisiones (8%) y tarifas fijas de servicio (S/. 2.00).
   */
  async getOrCreatePlatformWallet(tx?: Prisma.TransactionClient) {
    const client = tx || this.prisma;
    let treasuryUser = await client.user.findFirst({
      where: { email: 'treasury@chamba.pe' },
    });

    if (!treasuryUser) {
      treasuryUser = await client.user.create({
        data: {
          id: 'platform-treasury',
          email: 'treasury@chamba.pe',
          fullName: 'Tesorería CHAMBA',
          passwordHash: 'placeholder_hash',
        },
      });
    }

    return this.getOrCreateWallet(treasuryUser.id, tx);
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
   * Desglose:
   *  - Tarifa fija de servicio: S/. 2.00 para la plataforma (SERVICE_FEE).
   *  - Comisión de plataforma: 8% del precio pactado (COMMISSION).
   *  - Remanente neto: transferido a la billetera del técnico (RELEASE_ESCROW).
   * Invariante estricto: totalCustody === amountToWorker + commission + serviceFee.
   */
  async releaseEscrow(
    clientId: string,
    workerUserId: string,
    jobRequestId: string,
    releaseAmount?: number,
  ) {
    return this.prisma.$transaction(
      async (tx) => {
        // 1. Obtener billeteras de cliente, técnico y tesorería institucional
        const clientWallet = await this.getOrCreateWallet(clientId, tx);
        const workerWallet = await this.getOrCreateWallet(workerUserId, tx);
        const platformWallet = await this.getOrCreatePlatformWallet(tx);

        // 2. Bloqueo determinístico de billeteras para evitar interbloqueos (deadlocks)
        const sortedIds = [clientWallet.id, workerWallet.id, platformWallet.id].sort();
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

        const totalCustody = Math.abs(Number(holdEntry.amount));
        const agreedPrice = releaseAmount ?? (totalCustody > 2.0 ? Number((totalCustody - 2.0).toFixed(2)) : totalCustody);
        const serviceFee = Number((totalCustody - agreedPrice).toFixed(2));
        const commission = Number((agreedPrice * 0.08).toFixed(2));
        let amountToWorker = Number((agreedPrice - commission).toFixed(2));

        // Ajuste de precisión para garantizar la invariante exacta:
        // totalCustody = amountToWorker + commission + serviceFee
        const diff = Number((totalCustody - (amountToWorker + commission + serviceFee)).toFixed(2));
        amountToWorker = Number((amountToWorker + diff).toFixed(2));

        // 5. Registrar entrada inmutable positiva en la billetera del técnico
        const releaseEntry = await tx.ledgerEntry.create({
          data: {
            walletId: workerWallet.id,
            amount: amountToWorker,
            type: 'RELEASE_ESCROW',
            jobRequestId,
            description: `Liberación de pago por trabajo completado #${jobRequestId}`,
          },
        });

        // 6. Registrar comisiones y tarifas en la billetera institucional de tesorería
        if (commission > 0) {
          await tx.ledgerEntry.create({
            data: {
              walletId: platformWallet.id,
              amount: commission,
              type: 'COMMISSION',
              jobRequestId,
              description: `Comisión de servicio (8%) por trabajo #${jobRequestId}`,
            },
          });
        }

        if (serviceFee > 0) {
          await tx.ledgerEntry.create({
            data: {
              walletId: platformWallet.id,
              amount: serviceFee,
              type: 'SERVICE_FEE',
              jobRequestId,
              description: `Tarifa de servicio fija CHAMBA por trabajo #${jobRequestId}`,
            },
          });
        }

        // 7. Calcular el nuevo saldo total disponible del técnico
        const workerBalanceResult = await tx.$queryRaw<{ balance: number }[]>`
          SELECT COALESCE(SUM(amount), 0)::float AS balance
          FROM "ledger_entries"
          WHERE wallet_id = ${workerWallet.id}
        `;
        const workerAvailableBalance = workerBalanceResult[0]?.balance ?? 0;

        this.logger.log(
          `🔓 Escrow liberado: S/. ${amountToWorker.toFixed(2)} transferidos al técnico ${workerUserId}, comisión S/. ${commission.toFixed(2)}, tarifa S/. ${serviceFee.toFixed(2)} por job #${jobRequestId}`,
        );

        return {
          success: true,
          message: 'Fondos liberados exitosamente al técnico con liquidación contable de comisiones',
          releaseEntryId: releaseEntry.id,
          jobRequestId,
          totalCustody,
          amountReleased: amountToWorker,
          commission,
          serviceFee,
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
   * Reembolsa fondos de Escrow al cliente por cancelación o disputa.
   * Si el técnico ya estaba en camino, se le liquida una compensación del 10%
   * (mínimo S/. 5.00, máximo S/. 20.00).
   * Invariante estricto: totalCustody === refundAmount + compensation.
   */
  async refundEscrow(
    clientId: string,
    jobRequestId: string,
    isWorkerOnTheWay: boolean = false,
    workerUserId?: string,
  ) {
    return this.prisma.$transaction(
      async (tx) => {
        const clientWallet = await this.getOrCreateWallet(clientId, tx);
        let workerWallet: any = null;
        if (isWorkerOnTheWay && workerUserId) {
          workerWallet = await this.getOrCreateWallet(workerUserId, tx);
        }

        const walletIds = [clientWallet.id];
        if (workerWallet) walletIds.push(workerWallet.id);
        walletIds.sort();

        for (const wId of walletIds) {
          await tx.$queryRaw`SELECT id FROM "wallets" WHERE id = ${wId} FOR UPDATE`;
        }

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

        const existingReleaseOrRefund = await tx.ledgerEntry.findFirst({
          where: {
            jobRequestId,
            type: { in: ['RELEASE_ESCROW', 'REFUND_ESCROW'] },
          },
        });

        if (existingReleaseOrRefund) {
          throw new ConflictException(
            `Los fondos de la solicitud #${jobRequestId} ya fueron liberados o reembolsados previamente`,
          );
        }

        const totalCustody = Math.abs(Number(holdEntry.amount));
        let compensation = 0;
        let refundAmount = totalCustody;

        if (isWorkerOnTheWay && workerWallet) {
          const agreedPrice = totalCustody > 2.0 ? Number((totalCustody - 2.0).toFixed(2)) : totalCustody;
          const rawCompensation = Number((agreedPrice * 0.10).toFixed(2));
          compensation = Math.min(20.0, Math.max(5.0, rawCompensation));
          compensation = Math.min(compensation, totalCustody);
          refundAmount = Number((totalCustody - compensation).toFixed(2));

          // Registrar compensación para el técnico
          await tx.ledgerEntry.create({
            data: {
              walletId: workerWallet.id,
              amount: compensation,
              type: 'COMPENSATION',
              jobRequestId,
              description: `Compensación al chambeador por cancelación en camino #${jobRequestId}`,
            },
          });
        }

        // Registrar reembolso al cliente
        const refundEntry = await tx.ledgerEntry.create({
          data: {
            walletId: clientWallet.id,
            amount: refundAmount,
            type: 'REFUND_ESCROW',
            jobRequestId,
            description: `Reembolso de fondos de garantía para solicitud #${jobRequestId}`,
          },
        });

        // Verificación de invariante contable estricta
        if (Number((refundAmount + compensation).toFixed(2)) !== Number(totalCustody.toFixed(2))) {
          throw new BadRequestException('Error en el balance contable del reembolso');
        }

        this.logger.log(
          `↩️ Escrow reembolsado para job #${jobRequestId}: S/. ${refundAmount.toFixed(2)} a cliente ${clientId}, compensación S/. ${compensation.toFixed(2)} a técnico`,
        );

        return {
          success: true,
          message: 'Fondos de garantía reembolsados exitosamente',
          refundEntryId: refundEntry.id,
          jobRequestId,
          totalCustody,
          refundAmount,
          compensation,
        };
      },
      {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      },
    );
  }

  /**
   * Resuelve el Escrow de una disputa según la regla de negocio §5 (ALCANCE.md §8 L13):
   * - REFUND_CLIENT: Reembolso del 100% de custodia al cliente (incluyendo tarifa fija S/ 2.00).
   * - RELEASE_WORKER: Plataforma retiene tarifa S/ 2.00 y comisión 8%. Remanente al técnico.
   * - SPLIT: Plataforma retiene tarifa S/ 2.00. El remanente P se divide según workerSplitPercent.
   *          Comisión del 8% se aplica sobre la porción del trabajador.
   * Invariante estricto en todos los casos: totalCustody === refundClient + amountToWorker + commission + serviceFee.
   */
  async resolveDisputeEscrow(
    clientId: string,
    workerUserId: string,
    jobRequestId: string,
    verdict: string,
    workerSplitPercent: number = 50,
  ) {
    return this.prisma.$transaction(
      async (tx) => {
        const clientWallet = await this.getOrCreateWallet(clientId, tx);
        const workerWallet = await this.getOrCreateWallet(workerUserId, tx);
        const platformWallet = await this.getOrCreatePlatformWallet(tx);

        const walletIds = [clientWallet.id, workerWallet.id, platformWallet.id].sort();
        for (const wId of walletIds) {
          await tx.$queryRaw`SELECT id FROM "wallets" WHERE id = ${wId} FOR UPDATE`;
        }

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

        const existingReleaseOrRefund = await tx.ledgerEntry.findFirst({
          where: {
            jobRequestId,
            type: { in: ['RELEASE_ESCROW', 'REFUND_ESCROW'] },
          },
        });

        if (existingReleaseOrRefund) {
          throw new ConflictException(
            `Los fondos de la solicitud #${jobRequestId} ya fueron liquidados previamente`,
          );
        }

        const totalCustody = Math.abs(Number(holdEntry.amount));
        let refundClient = 0;
        let amountToWorker = 0;
        let commission = 0;
        let serviceFee = 0;

        if (verdict === 'REFUND_CLIENT') {
          // Reembolso total: la tarifa S/ 2.00 se reembolsa al cliente íntegra
          refundClient = totalCustody;
          await tx.ledgerEntry.create({
            data: {
              walletId: clientWallet.id,
              amount: refundClient,
              type: 'REFUND_ESCROW',
              jobRequestId,
              description: `Reembolso total de custodia por resolución de disputa #${jobRequestId}`,
            },
          });
        } else if (verdict === 'RELEASE_WORKER') {
          // A favor del técnico: plataforma retiene tarifa S/ 2 y comisión 8% de P
          serviceFee = totalCustody > 2.0 ? 2.0 : 0;
          const agreedPrice = Number((totalCustody - serviceFee).toFixed(2));
          commission = Number((agreedPrice * 0.08).toFixed(2));
          amountToWorker = Number((agreedPrice - commission).toFixed(2));

          const diff = Number((totalCustody - (amountToWorker + commission + serviceFee)).toFixed(2));
          if (diff !== 0) amountToWorker = Number((amountToWorker + diff).toFixed(2));

          await tx.ledgerEntry.create({
            data: {
              walletId: workerWallet.id,
              amount: amountToWorker,
              type: 'RELEASE_ESCROW',
              jobRequestId,
              description: `Liberación al técnico por resolución de disputa #${jobRequestId}`,
            },
          });

          if (commission > 0) {
            await tx.ledgerEntry.create({
              data: {
                walletId: platformWallet.id,
                amount: commission,
                type: 'COMMISSION',
                jobRequestId,
                description: `Comisión de servicio (8%) por resolución de disputa #${jobRequestId}`,
              },
            });
          }

          if (serviceFee > 0) {
            await tx.ledgerEntry.create({
              data: {
                walletId: platformWallet.id,
                amount: serviceFee,
                type: 'SERVICE_FEE',
                jobRequestId,
                description: `Tarifa de servicio fija CHAMBA retenida por disputa #${jobRequestId}`,
              },
            });
          }
        } else if (verdict === 'SPLIT') {
          // División: plataforma retiene tarifa S/ 2.00; el remanente P se divide
          serviceFee = totalCustody > 2.0 ? 2.0 : 0;
          const agreedPrice = Number((totalCustody - serviceFee).toFixed(2));
          const splitRatio = Math.max(0, Math.min(100, workerSplitPercent)) / 100;

          const workerGross = Number((agreedPrice * splitRatio).toFixed(2));
          const clientGross = Number((agreedPrice - workerGross).toFixed(2));

          commission = Number((workerGross * 0.08).toFixed(2));
          amountToWorker = Number((workerGross - commission).toFixed(2));
          refundClient = clientGross;

          const diff = Number((totalCustody - (refundClient + amountToWorker + commission + serviceFee)).toFixed(2));
          if (diff !== 0) {
            refundClient = Number((refundClient + diff).toFixed(2));
          }

          if (refundClient > 0) {
            await tx.ledgerEntry.create({
              data: {
                walletId: clientWallet.id,
                amount: refundClient,
                type: 'REFUND_ESCROW',
                jobRequestId,
                description: `Reembolso proporcional al cliente por resolución de disputa #${jobRequestId}`,
              },
            });
          }

          if (amountToWorker > 0) {
            await tx.ledgerEntry.create({
              data: {
                walletId: workerWallet.id,
                amount: amountToWorker,
                type: 'RELEASE_ESCROW',
                jobRequestId,
                description: `Pago proporcional al técnico por resolución de disputa #${jobRequestId}`,
              },
            });
          }

          if (commission > 0) {
            await tx.ledgerEntry.create({
              data: {
                walletId: platformWallet.id,
                amount: commission,
                type: 'COMMISSION',
                jobRequestId,
                description: `Comisión de plataforma por porción técnica en disputa #${jobRequestId}`,
              },
            });
          }

          if (serviceFee > 0) {
            await tx.ledgerEntry.create({
              data: {
                walletId: platformWallet.id,
                amount: serviceFee,
                type: 'SERVICE_FEE',
                jobRequestId,
                description: `Tarifa de servicio fija retenida por disputa #${jobRequestId}`,
              },
            });
          }
        }

        const computedSum = Number((refundClient + amountToWorker + commission + serviceFee).toFixed(2));
        if (computedSum !== Number(totalCustody.toFixed(2))) {
          throw new BadRequestException(
            `Invariante contable violado: suma S/. ${computedSum.toFixed(2)} != custodia S/. ${totalCustody.toFixed(2)}`,
          );
        }

        this.logger.log(
          `⚖️ Disputa resuelta en Escrow para job #${jobRequestId}: Veredicto=${verdict}, Custodia=${totalCustody}, Cliente=${refundClient}, Técnico=${amountToWorker}, Comisión=${commission}, Tarifa=${serviceFee}`,
        );

        return {
          success: true,
          message: 'Fondos de disputa liquidados exitosamente en el Libro Mayor',
          jobRequestId,
          totalCustody,
          verdict,
          refundClient,
          amountToWorker,
          commission,
          serviceFee,
        };
      },
      {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      },
    );
  }

  /**
   * Consulta auditoría financiera completa de un trabajo con desglose y verificación de invariante.
   */
  async getJobFinancialAudit(jobRequestId: string) {
    const entries = await this.prisma.ledgerEntry.findMany({
      where: { jobRequestId },
      orderBy: { createdAt: 'asc' },
    });

    const holdEntry = entries.find((e) => e.type === 'HOLD_ESCROW');
    const totalCustody = holdEntry ? Math.abs(Number(holdEntry.amount)) : 0;

    let refundClient = 0;
    let amountToWorker = 0;
    let commission = 0;
    let serviceFee = 0;
    let compensation = 0;

    for (const e of entries) {
      const amt = Number(e.amount);
      if (e.type === 'REFUND_ESCROW') refundClient += amt;
      else if (e.type === 'RELEASE_ESCROW') amountToWorker += amt;
      else if (e.type === 'COMMISSION') commission += amt;
      else if (e.type === 'SERVICE_FEE') serviceFee += amt;
      else if (e.type === 'COMPENSATION') compensation += amt;
    }

    refundClient = Number(refundClient.toFixed(2));
    amountToWorker = Number(amountToWorker.toFixed(2));
    commission = Number(commission.toFixed(2));
    serviceFee = Number(serviceFee.toFixed(2));
    compensation = Number(compensation.toFixed(2));

    const settledTotal = Number((refundClient + amountToWorker + commission + serviceFee + compensation).toFixed(2));
    const invariantPassed = totalCustody > 0 ? settledTotal === totalCustody : true;

    return {
      jobRequestId,
      totalCustody,
      refundClient,
      amountToWorker,
      commission,
      serviceFee,
      compensation,
      settledTotal,
      invariantPassed,
      invariantFormula: `${totalCustody.toFixed(2)} = ${refundClient.toFixed(2)} + ${amountToWorker.toFixed(2)} + ${commission.toFixed(2)} + ${serviceFee.toFixed(2)}${compensation > 0 ? ` + ${compensation.toFixed(2)}` : ''}`,
      entries: entries.map((e) => ({
        id: e.id,
        walletId: e.walletId,
        amount: Number(e.amount),
        type: e.type,
        description: e.description,
        createdAt: e.createdAt,
      })),
    };
  }

  /**
   * Consulta el resumen de tesorería institucional de la plataforma.
   */
  async getPlatformTreasurySummary() {
    const treasuryUser = await this.prisma.user.findFirst({
      where: { email: 'treasury@chamba.pe' },
    });
    if (!treasuryUser) return { availableBalance: 0, totalCommissions: 0, totalServiceFees: 0 };
    return this.getWalletSummary(treasuryUser.id);
  }

  /**
   * Vista consolidada de billeteras involucradas en un trabajo específico.
   */
  async getWalletsOverviewForJob(
    jobRequestId: string,
    requestingUser?: { id: string; role?: string },
  ) {
    const job = await this.prisma.jobRequest.findUnique({
      where: { id: jobRequestId },
      include: {
        worker: {
          include: { user: true },
        },
      },
    });
    if (!job) throw new NotFoundException(`Trabajo #${jobRequestId} no encontrado`);

    const isClient = requestingUser ? job.clientId === requestingUser.id : true;
    const workerUserId = job.worker?.userId;
    const isWorker = requestingUser
      ? workerUserId === requestingUser.id || job.workerId === requestingUser.id
      : true;
    const isSupport = requestingUser
      ? requestingUser.role === 'SUPPORT' || requestingUser.role === 'ADMIN'
      : true;

    if (requestingUser && !isClient && !isWorker && !isSupport) {
      throw new ForbiddenException('No tienes permiso para consultar la auditoría financiera de este trabajo');
    }

    const audit = await this.getJobFinancialAudit(jobRequestId);

    // Si es soporte o admin: ve todo (cliente, técnico, tesorería de plataforma)
    if (isSupport) {
      const clientWallet = await this.getWalletSummary(job.clientId);
      const workerWallet = workerUserId ? await this.getWalletSummary(workerUserId) : null;
      const platformWallet = await this.getPlatformTreasurySummary();
      return {
        jobId: jobRequestId,
        clientWallet,
        workerWallet,
        platformWallet,
        audit,
      };
    }

    // Si es cliente: ve únicamente su propia billetera, nunca el saldo del técnico ni de tesorería
    if (isClient) {
      const clientWallet = await this.getWalletSummary(job.clientId);
      return {
        jobId: jobRequestId,
        clientWallet,
        workerWallet: null,
        platformWallet: null,
        audit,
      };
    }

    // Si es chambeador: ve únicamente su propia billetera, nunca el saldo del cliente ni de tesorería
    if (isWorker && workerUserId) {
      const workerWallet = await this.getWalletSummary(workerUserId);
      return {
        jobId: jobRequestId,
        clientWallet: null,
        workerWallet,
        platformWallet: null,
        audit,
      };
    }

    throw new ForbiddenException('No tienes permiso para consultar la auditoría financiera de este trabajo');
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
