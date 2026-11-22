import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service.js';
import { EventsGateway } from '../events/events.gateway.js';
import { JobStateMachine, JobStatus } from '../common/job-state-machine.js';
import { FinanceService } from '../finance/finance.service.js';
import { CreateJobDto } from './dto/create-job.dto.js';
import { CreateBidDto } from './dto/create-bid.dto.js';
import { CounterBidDto } from './dto/counter-bid.dto.js';
import { FindJobsDto } from './dto/find-jobs.dto.js';
import { UpdateJobPhaseDto } from './dto/update-job-phase.dto.js';
import { CancelJobDto } from './dto/cancel-job.dto.js';
import { CreateRatingDto } from './dto/create-rating.dto.js';

@Injectable()
export class JobsService {
  private readonly logger = new Logger(JobsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly eventsGateway?: EventsGateway,
    private readonly financeService?: FinanceService,
  ) {}

  /**
   * Crea una nueva solicitud de trabajo (JobRequest) con estado inicial BUSCANDO
   * y genera un PIN de seguridad de 4 dígitos para validación presencial.
   */
  async createJob(userId: string, dto: CreateJobDto) {
    const pendingCount = await this.prisma.jobRequest.count({
      where: {
        clientId: userId,
        status: JobStatus.POR_CONFIRMAR,
      },
    });

    if (pendingCount > 0) {
      throw new BadRequestException(
        'Tienes un servicio pendiente de confirmación. Debes confirmar o reportar la labor anterior antes de publicar una nueva solicitud.',
      );
    }

    if (dto.budget < 20) {
      throw new BadRequestException('El presupuesto mínimo en CHAMBA es de S/ 20.00 (ALCANCE.md §3).');
    }

    const securityPin = Math.floor(1000 + Math.random() * 9000).toString();

    const createdJob = await this.prisma.jobRequest.create({
      data: {
        clientId: userId,
        title: dto.title,
        description: dto.description,
        category: dto.category,
        budget: dto.budget,
        district: dto.district,
        address: dto.address,
        reference: dto.reference,
        latitude: dto.latitude,
        longitude: dto.longitude,
        isSos: dto.isSos ?? false,
        urgency: dto.urgency ?? 'MEDIA',
        status: JobStatus.BUSCANDO,
        securityPin,
      },
      include: {
        client: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            district: true,
            address: true,
          },
        },
        bids: true,
      },
    });

    this.logger.log(`📋 Chamba creada: ${createdJob.id} ("${createdJob.title}") por cliente ${userId}`);

    // Notificar en tiempo real a técnicos disponibles
    if (this.eventsGateway?.server) {
      this.eventsGateway.server.emit('newJobAvailable', {
        id: createdJob.id,
        title: createdJob.title,
        category: createdJob.category,
        budget: createdJob.budget,
        district: createdJob.district,
        isSos: createdJob.isSos,
        createdAt: createdJob.createdAt,
      });
    }

    return createdJob;
  }

  /**
   * Lista chambas filtradas por rol del usuario o estado.
   */
  async findAll(userId: string, query: FindJobsDto) {
    if (query.role === 'client') {
      return this.prisma.jobRequest.findMany({
        where: {
          clientId: userId,
          ...(query.status ? { status: query.status } : {}),
        },
        include: {
          client: {
            select: {
              id: true,
              fullName: true,
              email: true,
              phone: true,
            },
          },
          worker: {
            include: {
              user: {
                select: {
                  id: true,
                  fullName: true,
                  email: true,
                  phone: true,
                },
              },
            },
          },
          bids: {
            include: {
              worker: {
                include: {
                  user: {
                    select: {
                      id: true,
                      fullName: true,
                      email: true,
                      phone: true,
                    },
                  },
                },
              },
            },
            orderBy: { createdAt: 'desc' },
          },
        },
        orderBy: { createdAt: 'desc' },
      });
    }

    if (query.role === 'worker') {
      const workerProfile = await this.prisma.workerProfile.findUnique({
        where: { userId },
      });

      const workerFilter = workerProfile
        ? [
            { status: { in: [JobStatus.BUSCANDO, JobStatus.NEGOCIANDO] } },
            { workerId: workerProfile.id },
            { bids: { some: { workerId: workerProfile.id } } },
          ]
        : [{ status: { in: [JobStatus.BUSCANDO, JobStatus.NEGOCIANDO] } }];

      return this.prisma.jobRequest.findMany({
        where: query.status
          ? { status: query.status }
          : { OR: workerFilter },
        include: {
          client: {
            select: {
              id: true,
              fullName: true,
              district: true,
            },
          },
          bids: {
            include: {
              worker: {
                include: {
                  user: {
                    select: {
                      id: true,
                      fullName: true,
                    },
                  },
                },
              },
            },
            orderBy: { createdAt: 'desc' },
          },
        },
        orderBy: { createdAt: 'desc' },
      });
    }

    // Consulta general por defecto
    return this.prisma.jobRequest.findMany({
      where: query.status ? { status: query.status } : {},
      include: {
        client: {
          select: {
            id: true,
            fullName: true,
            district: true,
          },
        },
        bids: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Obtiene el detalle de una chamba por ID (§3, §8 L14).
   * Aplica políticas de privacidad y protección de datos:
   * - El PIN de seguridad solo se expone al cliente o soporte.
   * - El correo del cliente se oculta a no-soporte.
   * - La dirección exacta y teléfono del cliente solo se revelan al chambeador asignado tras el depósito de garantía.
   */
  async findOne(jobId: string, requestingUser?: { id: string; role?: string }) {
    const job = await this.prisma.jobRequest.findUnique({
      where: { id: jobId },
      include: {
        client: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            district: true,
            address: true,
          },
        },
        worker: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                phone: true,
              },
            },
          },
        },
        bids: {
          include: {
            worker: {
              include: {
                user: {
                  select: {
                    id: true,
                    fullName: true,
                  },
                },
              },
            },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!job) {
      throw new NotFoundException(`Solicitud de trabajo con ID "${jobId}" no encontrada`);
    }

    const isClient = requestingUser ? job.clientId === requestingUser.id : true;
    const workerUserId = job.worker?.user?.id;
    const isAssignedWorker = requestingUser
      ? workerUserId === requestingUser.id || job.workerId === requestingUser.id
      : false;
    const isSupport = requestingUser
      ? requestingUser.role === 'SUPPORT' || requestingUser.role === 'ADMIN'
      : false;

    // Estados posteriores a la retención de garantía (depósito confirmado)
    const isPostDeposit = [
      JobStatus.EN_CAMINO,
      JobStatus.EN_SITIO,
      JobStatus.EN_EJECUCION,
      JobStatus.POR_CONFIRMAR,
      JobStatus.COMPLETADA,
      JobStatus.EN_DISPUTA,
    ].includes(job.status as unknown as JobStatus);

    const canSeeExactAddress = isClient || isSupport || (isAssignedWorker && isPostDeposit);
    const canSeePhone = isClient || isSupport || (isAssignedWorker && isPostDeposit);

    const sanitizedClient = job.client
      ? {
          id: job.client.id,
          fullName: job.client.fullName,
          district: job.client.district,
          ...(canSeeExactAddress ? { address: job.client.address } : {}),
          ...(canSeePhone ? { phone: job.client.phone } : {}),
          ...(isSupport ? { email: job.client.email } : {}),
        }
      : null;

    const sanitizedSecurityPin = (isClient || isSupport) ? job.securityPin : null;

    return {
      ...job,
      securityPin: sanitizedSecurityPin,
      client: sanitizedClient,
    };
  }

  /**
   * Registra una propuesta económica (Bid) por parte de un trabajador.
   * Si la solicitud estaba en BUSCANDO, pasa a NEGOCIANDO.
   */
  async createBid(userId: string, jobId: string, dto: CreateBidDto) {
    const workerProfile = await this.prisma.workerProfile.findUnique({
      where: { userId },
      include: { user: true },
    });

    if (!workerProfile) {
      throw new NotFoundException('Perfil de trabajador no encontrado para este usuario');
    }

    const job = await this.prisma.jobRequest.findUnique({
      where: { id: jobId },
    });

    if (!job) {
      throw new NotFoundException(`Solicitud ${jobId} no encontrada`);
    }

    if (job.clientId === userId) {
      throw new ForbiddenException('No puedes postularte ni enviar ofertas a tu propia solicitud de chamba');
    }

    if (job.status !== JobStatus.BUSCANDO && job.status !== JobStatus.NEGOCIANDO) {
      throw new BadRequestException(
        `No se puede ofertar en una solicitud con estado "${job.status}"`,
      );
    }

    if (dto.amount < 20) {
      throw new BadRequestException('El monto mínimo para una oferta en CHAMBA es de S/ 20.00 (ALCANCE.md §3).');
    }

    const newBid = await this.prisma.bid.create({
      data: {
        jobRequestId: jobId,
        workerId: workerProfile.id,
        amount: dto.amount,
        message: dto.message,
        estimatedEtaMinutes: dto.estimatedEtaMinutes ?? 20,
        voiceNoteUrl: dto.voiceNoteUrl,
        status: 'PENDIENTE',
      },
    });

    // Si el estado era BUSCANDO, pasa a NEGOCIANDO
    if (job.status === JobStatus.BUSCANDO) {
      JobStateMachine.assertCanTransition(job.status as unknown as JobStatus, JobStatus.NEGOCIANDO);
      await this.prisma.jobRequest.update({
        where: { id: jobId },
        data: { status: JobStatus.NEGOCIANDO },
      });
    }

    // Emitir por Socket.IO a la sala del trabajo
    if (this.eventsGateway?.server) {
      const room = `job:${jobId}`;
      this.eventsGateway.server.to(room).emit('newBidReceived', {
        id: newBid.id,
        jobRequestId: jobId,
        workerId: workerProfile.id,
        workerName: workerProfile.user?.fullName || 'Técnico Especialista',
        workerRating: workerProfile.rating,
        workerCompletedJobs: workerProfile.completedJobs,
        amount: Number(newBid.amount),
        message: newBid.message,
        estimatedArrival: `${newBid.estimatedEtaMinutes || 20} min`,
        createdAt: newBid.createdAt instanceof Date ? newBid.createdAt.toISOString() : (newBid.createdAt || new Date().toISOString()),
        status: newBid.status,
      });
    }

    this.logger.log(`💼 Oferta de S/. ${dto.amount} creada en job ${jobId} por trabajador ${workerProfile.id}`);
    return newBid;
  }

  /**
   * Registra una contraoferta (§3, §8 L14).
   * Valida autorización: solo el cliente o el técnico proponente pueden contraofertar.
   */
  async counterBid(userId: string, jobId: string, bidId: string, dto: CounterBidDto) {
    const bid = await this.prisma.bid.findUnique({
      where: { id: bidId },
      include: {
        jobRequest: true,
        worker: {
          include: { user: true },
        },
      },
    });

    if (!bid || bid.jobRequestId !== jobId) {
      throw new NotFoundException(`Oferta ${bidId} no encontrada en la solicitud ${jobId}`);
    }

    const isClient = bid.jobRequest.clientId === userId;
    const isBidWorker = bid.worker?.userId === userId || bid.workerId === userId;
    if (!isClient && !isBidWorker) {
      throw new ForbiddenException('Solo el cliente de la chamba o el trabajador proponente pueden contraofertar');
    }

    const updatedBid = await this.prisma.bid.update({
      where: { id: bidId },
      data: {
        counterAmount: dto.counterAmount,
        status: 'CONTRAOFERTA',
      },
    });

    if (this.eventsGateway?.server) {
      const room = `job:${jobId}`;
      this.eventsGateway.server.to(room).emit('counterOfferReceived', {
        jobRequestId: jobId,
        bidId: bid.id,
        counterAmount: dto.counterAmount,
        note: dto.note,
        timestamp: new Date().toISOString(),
      });
    }

    return updatedBid;
  }

  /**
   * El cliente acepta una oferta. La chamba pasa a ACEPTADA.
   * Se asigna el plazo límite de 15 minutos para depósito de garantía.
   */
  async acceptBid(userId: string, jobId: string, bidId: string) {
    const job = await this.prisma.jobRequest.findUnique({
      where: { id: jobId },
    });

    if (!job) {
      throw new NotFoundException(`Solicitud ${jobId} no encontrada`);
    }

    if (job.clientId !== userId) {
      throw new ForbiddenException('Solo el cliente que creó la solicitud puede aceptar una oferta');
    }

    JobStateMachine.assertCanTransition(job.status as unknown as JobStatus, JobStatus.ACEPTADA);

    const bid = await this.prisma.bid.findUnique({
      where: { id: bidId },
    });

    if (!bid || bid.jobRequestId !== jobId) {
      throw new NotFoundException(`Oferta ${bidId} no encontrada en la solicitud ${jobId}`);
    }

    const depositDeadline = new Date(Date.now() + 15 * 60 * 1000); // 15 minutos

    // Actualizar oferta aceptada
    await this.prisma.bid.update({
      where: { id: bidId },
      data: { status: 'ACEPTADA' },
    });

    // Rechazar otras ofertas de esta solicitud
    await this.prisma.bid.updateMany({
      where: {
        jobRequestId: jobId,
        id: { not: bidId },
      },
      data: { status: 'RECHAZADA' },
    });

    // Actualizar solicitud de trabajo a ACEPTADA
    const updatedJob = await this.prisma.jobRequest.update({
      where: { id: jobId },
      data: {
        status: JobStatus.ACEPTADA,
        workerId: bid.workerId,
        agreedPrice: bid.amount,
        acceptedAt: new Date(),
        depositDeadline,
      },
      include: {
        bids: true,
        worker: true,
        client: true,
      },
    });

    if (this.eventsGateway?.server) {
      const room = `job:${jobId}`;
      this.eventsGateway.server.to(room).emit('bidAccepted', {
        jobRequestId: jobId,
        bidId: bid.id,
        agreedAmount: Number(bid.amount),
        acceptedBy: userId,
        depositDeadline: depositDeadline.toISOString(),
        timestamp: new Date().toISOString(),
      });
    }

    this.logger.log(`✅ Oferta ${bidId} aceptada para job ${jobId}. Chamba pasa a ACEPTADA.`);
    return updatedJob;
  }

  /**
   * Actualiza la fase de una chamba con validaciones de rol y máquina de estados (ALCANCE.md §8 L4)
   */
  async updatePhase(userId: string, jobId: string, dto: UpdateJobPhaseDto) {
    const job = await this.prisma.jobRequest.findUnique({
      where: { id: jobId },
      include: {
        worker: true,
      },
    });

    if (!job) {
      throw new NotFoundException(`Solicitud ${jobId} no encontrada`);
    }

    // Validar transición según la máquina de estados
    JobStateMachine.assertCanTransition(
      job.status as unknown as JobStatus,
      dto.phase as unknown as JobStatus,
    );

    const isClient = job.clientId === userId;
    let isWorker = false;
    if (!isClient) {
      if (job.worker?.userId === userId || job.workerId === userId) {
        isWorker = true;
      } else {
        const profile = await this.prisma.workerProfile.findUnique({
          where: { userId },
        });
        if (profile && profile.id === job.workerId) {
          isWorker = true;
        }
      }
    }

    if (!isClient && !isWorker) {
      throw new ForbiddenException('No tienes permiso para actualizar esta chamba');
    }

    // Reglas de roles por fase (§4.2, §4.3, §7, §8 L4):
    // 1. Fases del chambeador: EN_CAMINO, EN_SITIO, EN_EJECUCION, POR_CONFIRMAR
    const workerPhases = [
      JobStatus.EN_CAMINO,
      JobStatus.EN_SITIO,
      JobStatus.EN_EJECUCION,
      JobStatus.POR_CONFIRMAR,
    ];

    if (workerPhases.includes(dto.phase)) {
      if (!isWorker) {
        throw new ForbiddenException('Solo el chambeador asignado puede avanzar esta fase');
      }
    }

    // 2. Fases del cliente: COMPLETADA
    if (dto.phase === JobStatus.COMPLETADA) {
      if (isWorker && !isClient) {
        throw new ForbiddenException('El chambeador no puede auto-aprobarse el trabajo');
      }
      if (!isClient) {
        throw new ForbiddenException('Solo el cliente puede confirmar la finalización del trabajo');
      }
    }

    // Validaciones específicas de contenido según la fase
    const updateData: any = {
      status: dto.phase,
    };

    if (dto.phase === JobStatus.EN_EJECUCION) {
      if (!dto.pin || dto.pin.trim() !== job.securityPin) {
        throw new BadRequestException('PIN de seguridad incorrecto. Solicita el código de 4 dígitos al cliente.');
      }
      if (!dto.photoBefore || dto.photoBefore.trim() === '') {
        throw new BadRequestException('La foto del antes es obligatoria para iniciar la ejecución del trabajo.');
      }
      updateData.isPinVerified = true;
      updateData.beforePhotoUrl = dto.photoBefore;
    }

    if (dto.phase === JobStatus.POR_CONFIRMAR) {
      if (!dto.photoAfter || dto.photoAfter.trim() === '') {
        throw new BadRequestException('La foto del después es obligatoria para finalizar el trabajo.');
      }
      updateData.afterPhotoUrl = dto.photoAfter;
      updateData.autoReleaseAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    }

    if (dto.phase === JobStatus.COMPLETADA) {
      updateData.confirmedAt = new Date();
    }

    const updatedJob = await this.prisma.jobRequest.update({
      where: { id: jobId },
      data: updateData,
      include: {
        bids: true,
        worker: true,
        client: true,
      },
    });

    if (this.eventsGateway?.server) {
      const room = `job:${jobId}`;
      this.eventsGateway.server.to(room).emit('jobPhaseUpdated', {
        jobRequestId: jobId,
        status: dto.phase,
        isPinVerified: updatedJob.isPinVerified,
        beforePhotoUrl: updatedJob.beforePhotoUrl,
        afterPhotoUrl: updatedJob.afterPhotoUrl,
        confirmedAt: updatedJob.confirmedAt?.toISOString(),
        updatedBy: userId,
        timestamp: new Date().toISOString(),
      });
    }

    this.logger.log(`🔄 Chamba ${jobId} avanzó a fase ${dto.phase} por usuario ${userId}`);
    return updatedJob;
  }

  @Cron(CronExpression.EVERY_5_MINUTES)
  async handleAutoReleaseCron() {
    this.logger.debug('Ejecutando cron de auto-liberación de chambas expiradas (24h)...');
    return this.autoReleaseExpiredConfirmedJobs(24);
  }

  /**
   * Liberación automática a las 24 h sin respuesta ni reclamo (§3, §8 L5, §8 L12).
   * - Libera el pago en garantía con comisión del 8% a través de FinanceService.
   * - Se salta trabajos en estado EN_DISPUTA o con disputas activas.
   * - Es estrictamente idempotente: dos ejecuciones consecutivas NO duplican asientos.
   * - Notifica a ambas partes vía Socket.IO (cliente y chambeador).
   */
  async autoReleaseExpiredConfirmedJobs(hoursLimit: number = 24) {
    const now = new Date();
    const threshold = new Date(Date.now() - hoursLimit * 60 * 60 * 1000);
    const expiredJobs = await this.prisma.jobRequest.findMany({
      where: {
        status: JobStatus.POR_CONFIRMAR,
        OR: [
          { autoReleaseAt: { lte: now } },
          { autoReleaseAt: null, updatedAt: { lte: threshold } },
        ],
        disputes: {
          none: {
            status: { in: ['ABIERTA', 'EN_REVISION'] },
          },
        },
      },
      include: {
        worker: true,
        disputes: true,
      },
    });

    const releasedJobs = [];
    for (const job of expiredJobs) {
      if (job.status === JobStatus.EN_DISPUTA) {
        continue;
      }

      // Idempotencia: Verificar que no exista ya un asiento RELEASE_ESCROW para este jobRequestId
      const alreadyReleased = await this.prisma.ledgerEntry.findFirst({
        where: {
          jobRequestId: job.id,
          type: 'RELEASE_ESCROW',
        },
      });

      if (alreadyReleased) {
        this.logger.warn(
          `Chamba #${job.id} ya contaba con liberación en ledger. Se omite duplicación de asiento.`,
        );
        continue;
      }

      const workerUserId = job.worker?.userId;
      if (!workerUserId) {
        this.logger.error(`Chamba #${job.id} en POR_CONFIRMAR sin técnico asignado.`);
        continue;
      }

      // 1. Liberar pago en custodia con comisión a través de FinanceService
      if (this.financeService) {
        await this.financeService.releaseEscrow(job.clientId, workerUserId, job.id);
      }

      // 2. Transicionar estado a COMPLETADA
      const updatedJob = await this.prisma.jobRequest.update({
        where: { id: job.id },
        data: {
          status: JobStatus.COMPLETADA,
          confirmedAt: new Date(),
        },
      });

      // 3. Notificar en tiempo real a ambas partes
      if (this.eventsGateway?.server) {
        const room = `job:${job.id}`;
        this.eventsGateway.server.to(room).emit('jobPhaseUpdated', {
          jobRequestId: job.id,
          status: JobStatus.COMPLETADA,
          confirmedAt: updatedJob.confirmedAt?.toISOString(),
          autoReleased: true,
          timestamp: new Date().toISOString(),
        });

        this.eventsGateway.server.to(room).emit('jobAutoReleased', {
          jobRequestId: job.id,
          clientId: job.clientId,
          workerUserId,
          message:
            'El pago ha sido liberado automáticamente al técnico tras cumplirse las 24 horas sin reclamo.',
          timestamp: new Date().toISOString(),
        });
      }

      this.logger.log(`⏰ Chamba #${job.id} liberada automáticamente tras ${hoursLimit}h sin respuesta.`);
      releasedJobs.push(updatedJob);
    }

    return releasedJobs;
  }

  /**
   * Cancelación de chamba según matriz de ALCANCE.md §4:
   * - Antes de depositar (BUSCANDO, NEGOCIANDO, ACEPTADA sin pagar): sin movimiento de dinero.
   * - Depositado, técnico aún no sale: Cliente cancela -> reembolso total.
   * - Técnico EN_CAMINO cancelado por cliente: Compensación 10% (mín S/ 5, máx S/ 20) al técnico y resto reembolsado.
   * - Técnico no llega (>30 min retraso): Reembolso total + incidente de reputación al técnico.
   * - Chambeador cancela tras el depósito: Reembolso total + incidente de reputación al técnico.
   * - Si el técnico acumula 3 o más incidentes en 30 días -> suspensión temporal (SUSPENDED).
   * - Con PIN validado en adelante (EN_EJECUCION, POR_CONFIRMAR, COMPLETADA): Solo con soporte (Disputa §5).
   * - La tarifa de servicio (S/ 2) se reembolsa en toda cancelación.
   */
  async cancelJob(userId: string, jobId: string, dto: CancelJobDto) {
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
      throw new NotFoundException(`Solicitud ${jobId} no encontrada`);
    }

    const isClient = job.clientId === userId;
    const workerUserId = job.worker?.userId;
    const isWorker = workerUserId === userId;

    if (!isClient && !isWorker) {
      throw new ForbiddenException('No tienes permiso para cancelar esta solicitud');
    }

    // Regla: Desde PIN validado (EN_EJECUCION en adelante), no se puede cancelar directamente
    if (
      job.status === JobStatus.EN_EJECUCION ||
      job.status === JobStatus.POR_CONFIRMAR ||
      job.status === JobStatus.COMPLETADA
    ) {
      throw new BadRequestException(
        'El servicio ya cuenta con validación presencial de PIN o está por confirmar. Para cualquier reclamo debes abrir una Disputa con soporte (§5).',
      );
    }

    if (job.status === JobStatus.CANCELADA) {
      throw new BadRequestException('Esta solicitud ya ha sido cancelada previamente.');
    }

    // Verificar si existen fondos retenidos en custodia
    const holdEntry = await this.prisma.ledgerEntry.findFirst({
      where: {
        jobRequestId: jobId,
        type: 'HOLD_ESCROW',
      },
    });

    let refundResult: any = null;

    if (holdEntry && this.financeService) {
      if (isClient) {
        if (job.status === JobStatus.EN_CAMINO && !dto.isWorkerDelay) {
          // Cliente cancela con técnico en camino: compensación 10% (mín S/ 5, máx S/ 20) al técnico
          refundResult = await this.financeService.refundEscrow(
            job.clientId,
            jobId,
            true,
            workerUserId,
          );
        } else if (dto.isWorkerDelay) {
          // Técnico no llega (>30 min retraso): Reembolso total + incidente de reputación
          refundResult = await this.financeService.refundEscrow(
            job.clientId,
            jobId,
            false,
          );
          await this._applyReputationIncident(job.workerId, workerUserId);
        } else {
          // Depositado, técnico aún no sale: Reembolso total
          refundResult = await this.financeService.refundEscrow(
            job.clientId,
            jobId,
            false,
          );
        }
      } else if (isWorker) {
        // Chambeador cancela tras el depósito: Reembolso total + incidente de reputación
        refundResult = await this.financeService.refundEscrow(
          job.clientId,
          jobId,
          false,
        );
        await this._applyReputationIncident(job.workerId, workerUserId);
      }
    }

    // Actualizar estado a CANCELADA
    const updatedJob = await this.prisma.jobRequest.update({
      where: { id: jobId },
      data: {
        status: JobStatus.CANCELADA,
      },
      include: {
        bids: true,
        worker: true,
        client: true,
      },
    });

    if (this.eventsGateway?.server) {
      const room = `job:${jobId}`;
      this.eventsGateway.server.to(room).emit('jobCancelled', {
        jobRequestId: jobId,
        cancelledBy: userId,
        reason: dto.reason,
        refundResult,
        timestamp: new Date().toISOString(),
      });
    }

    this.logger.log(`🚫 Chamba ${jobId} cancelada por usuario ${userId}. Razón: ${dto.reason}`);
    return {
      job: updatedJob,
      refundResult,
    };
  }

  private async _applyReputationIncident(workerProfileId?: string | null, workerUserId?: string) {
    if (!workerProfileId) return;

    try {
      const updatedProfile = await this.prisma.workerProfile.update({
        where: { id: workerProfileId },
        data: {
          incidentsCount: { increment: 1 },
        },
      });

      this.logger.warn(
        `⚠️ Incidente de reputación aplicado al técnico ${workerProfileId}. Total incidentes: ${updatedProfile.incidentsCount}`,
      );

      if (updatedProfile.incidentsCount >= 3 && workerUserId) {
        await this.prisma.user.update({
          where: { id: workerUserId },
          data: { status: 'SUSPENDED' },
        });
        this.logger.error(
          `🚫 Técnico ${workerProfileId} suspendido por acumular 3 o más incidentes de reputación.`,
        );
      }
    } catch (e) {
      this.logger.error(`Error al registrar incidente de reputación: ${e}`);
    }
  }

  /**
   * Calificación mutua (1 a 5 estrellas + comentario) y propina opcional (§6, §8 L8).
   * La propina va 100% al técnico sin comisión.
   */
  async createRating(userId: string, jobId: string, dto: CreateRatingDto) {
    const job = await this.prisma.jobRequest.findUnique({
      where: { id: jobId },
      include: {
        worker: {
          include: {
            user: true,
          },
        },
        client: true,
      },
    });

    if (!job) {
      throw new NotFoundException(`Solicitud #${jobId} no encontrada`);
    }

    if (job.status !== JobStatus.COMPLETADA) {
      throw new BadRequestException('Solo se pueden emitir calificaciones para chambas COMPLETADAS');
    }

    const isClient = job.clientId === userId;
    const workerUserId = job.worker?.userId;
    const isWorker = workerUserId === userId;

    if (!isClient && !isWorker) {
      throw new ForbiddenException('No tienes permiso para calificar esta chamba');
    }

    const toUserId = isClient ? workerUserId! : job.clientId;
    const tip = isClient && dto.tipAmount ? Number(dto.tipAmount) : 0;

    const rating = await this.prisma.rating.create({
      data: {
        jobRequestId: jobId,
        fromUserId: userId,
        toUserId,
        stars: dto.stars,
        comment: dto.comment,
        tipAmount: tip,
      },
    });

    // Si se calificó al técnico, recalcular promedio de rating en su WorkerProfile
    if (toUserId === workerUserId && job.workerId) {
      try {
        const ratings = await this.prisma.rating.findMany({
          where: { toUserId: workerUserId },
          select: { stars: true },
        });

        if (ratings.length > 0) {
          const avg = ratings.reduce((sum, r) => sum + r.stars, 0) / ratings.length;
          await this.prisma.workerProfile.update({
            where: { id: job.workerId },
            data: { rating: Number(avg.toFixed(1)) },
          });
        }
      } catch (e) {
        this.logger.warn(`No se pudo actualizar el promedio del técnico: ${e}`);
      }
    }

    if (this.eventsGateway?.server) {
      const room = `job:${jobId}`;
      this.eventsGateway.server.to(room).emit('jobRated', {
        jobRequestId: jobId,
        fromUserId: userId,
        toUserId,
        stars: dto.stars,
        comment: dto.comment,
        tipAmount: tip,
        timestamp: new Date().toISOString(),
      });
    }

    this.logger.log(`⭐ Calificación registrada para chamba #${jobId} (${dto.stars} estrellas de ${userId} a ${toUserId})`);
    return rating;
  }

  /**
   * Genera el recibo formal de la chamba completada (§6, §7, §8 L8, §8 L14):
   * Desglose: precio P, comisión 8%, tarifa S/ 2, propina, fotos y fechas.
   * Valida autorización: solo cliente, trabajador asignado o soporte/admin.
   * Scoping de privacidad:
   * - Cliente ve lo que pagó (precio, tarifa, propina, total pagado); comisión y neto del técnico se ocultan.
   * - Trabajador ve su liquidación (precio, comisión, propina, neto a recibir); tarifa de servicio y total pagado por cliente se ocultan.
   * - Soporte/Admin ve la vista completa.
   */
  async getJobReceipt(jobId: string, requestingUser?: { id: string; role?: string }) {
    const job = await this.prisma.jobRequest.findUnique({
      where: { id: jobId },
      include: {
        client: true,
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

    const isClient = requestingUser ? job.clientId === requestingUser.id : true;
    const workerUserId = job.worker?.user?.id;
    const isWorker = requestingUser
      ? workerUserId === requestingUser.id || job.workerId === requestingUser.id
      : true;
    const isSupport = requestingUser
      ? requestingUser.role === 'SUPPORT' || requestingUser.role === 'ADMIN'
      : true;

    if (requestingUser && !isClient && !isWorker && !isSupport) {
      throw new ForbiddenException('No tienes permiso para consultar el recibo de este trabajo');
    }

    const ratings = await this.prisma.rating.findMany({
      where: { jobRequestId: jobId },
    });

    const tip = ratings.reduce((sum, r) => sum + Number(r.tipAmount ?? 0), 0);
    const agreedPrice = Number(job.budget);
    const commission = Number((agreedPrice * 0.08).toFixed(2));
    const serviceFee = 2.0;
    const totalPaidByClient = Number((agreedPrice + serviceFee + tip).toFixed(2));
    const totalReceivedByWorker = Number((agreedPrice - commission + tip).toFixed(2));

    return {
      jobId: job.id,
      title: job.title,
      category: job.category,
      clientName: job.client?.fullName ?? 'Cliente',
      workerName: job.worker?.user?.fullName ?? 'Técnico Especialista',
      agreedPrice,
      commission: isClient && !isSupport ? null : commission,
      serviceFee: isWorker && !isSupport ? null : serviceFee,
      tipAmount: tip,
      totalPaidByClient: isWorker && !isSupport ? null : totalPaidByClient,
      totalReceivedByWorker: isClient && !isSupport ? null : totalReceivedByWorker,
      beforePhotoUrl: job.beforePhotoUrl,
      afterPhotoUrl: job.afterPhotoUrl,
      completedAt: job.confirmedAt ?? job.updatedAt,
      district: job.district,
    };
  }
}
