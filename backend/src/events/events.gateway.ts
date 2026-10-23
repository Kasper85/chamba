import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Logger, UseGuards, UsePipes, ValidationPipe } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { RedisService } from '../redis/redis.service.js';
import { SendBidDto } from './dto/send-bid.dto.js';
import { JoinJobRoomDto } from './dto/join-job-room.dto.js';
import { WsJwtGuard } from './guards/ws-jwt.guard.js';

export interface AuthenticatedUserPayload {
  sub: string;
  email: string;
  fullName?: string;
  phone?: string;
}

@WebSocketGateway({
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
    credentials: true,
  },
  namespace: '/',
})
export class EventsGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(EventsGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly redisService: RedisService,
  ) {}

  afterInit() {
    this.logger.log('⚡ EventsGateway inicializado para comunicación en tiempo real.');
  }

  /**
   * Valida la conexión entrante con JWT y registra el estado del usuario en Redis.
   */
  async handleConnection(client: Socket) {
    try {
      const authHeader = client.handshake.headers.authorization;
      const authToken = client.handshake.auth?.token;
      const queryToken = client.handshake.query?.token as string | undefined;

      const rawToken =
        authToken ||
        (authHeader?.startsWith('Bearer ') ? authHeader.split(' ')[1] : authHeader) ||
        queryToken;

      if (!rawToken) {
        this.logger.warn(`Conexión rechazada: Socket ${client.id} sin token JWT.`);
        client.disconnect(true);
        return;
      }

      const secret = this.configService.get<string>(
        'JWT_SECRET',
        'chamba_desarrollo_secreto_super_seguro_jwt_2026',
      );

      const payload = this.jwtService.verify<AuthenticatedUserPayload>(rawToken, { secret });
      client.data.user = payload;
      const userId = payload.sub;

      // 1. Guardar estado efímero del usuario como online en Redis
      await this.redisService.setUserOnline(userId, client.id);

      // 2. Unir el socket a su sala personal directa 'user:{userId}' para mensajes privados
      await client.join(`user:${userId}`);

      this.logger.log(
        `🟢 Usuario conectado: ${userId} (${payload.email}) en socket: ${client.id}`,
      );
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      this.logger.warn(`Conexión rechazada: Token inválido en socket ${client.id} (${message}).`);
      client.disconnect(true);
    }
  }

  /**
   * Al desconectarse, actualiza el estado de conexión del usuario en Redis.
   */
  async handleDisconnect(client: Socket) {
    const user = client.data?.user as AuthenticatedUserPayload | undefined;
    if (user?.sub) {
      await this.redisService.setUserOffline(user.sub, client.id);
      this.logger.log(`🔴 Usuario desconectado: ${user.sub} del socket: ${client.id}`);
    } else {
      this.logger.debug(`Socket desconectado: ${client.id}`);
    }
  }

  /**
   * Suscribe el socket de un cliente o trabajador a la sala específica de una solicitud.
   * Ej: 'job:job-101'
   */
  @SubscribeMessage('joinJobRoom')
  async handleJoinJobRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() dto: JoinJobRoomDto,
  ) {
    const room = `job:${dto.jobRequestId}`;
    await client.join(room);

    this.logger.log(`Socket ${client.id} se unió a la sala: ${room}`);

    const payload = {
      event: 'joinedJobRoom',
      success: true,
      jobRequestId: dto.jobRequestId,
      room,
    };
    client.emit('joinedJobRoom', payload);
    return payload;
  }

  /**
   * Desuscribe el socket de la sala de la solicitud.
   */
  @SubscribeMessage('leaveJobRoom')
  async handleLeaveJobRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() dto: JoinJobRoomDto,
  ) {
    const room = `job:${dto.jobRequestId}`;
    await client.leave(room);

    const payload = {
      event: 'leftJobRoom',
      success: true,
      jobRequestId: dto.jobRequestId,
    };
    client.emit('leftJobRoom', payload);
    return payload;
  }

  /**
   * Un trabajador envía una oferta ('sendBid') para una solicitud.
   * Se emite instantáneamente el evento 'newBidReceived' a todos los conectados a la sala 'job:{jobRequestId}'.
   */
  @SubscribeMessage('sendBid')
  @UseGuards(WsJwtGuard)
  @UsePipes(new ValidationPipe({ transform: true }))
  async handleSendBid(
    @ConnectedSocket() client: Socket,
    @MessageBody() dto: SendBidDto,
  ) {
    const user = client.data?.user as AuthenticatedUserPayload;
    const room = `job:${dto.jobRequestId}`;

    const bidData = {
      id: `bid-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`,
      jobRequestId: dto.jobRequestId,
      workerId: user?.sub || 'worker-unknown',
      workerName: user?.fullName || user?.email || 'Técnico Especialista',
      amount: dto.amount,
      message: dto.message || 'Propuesta de trabajo enviada',
      estimatedArrival: dto.estimatedArrival || '20 min',
      includesMaterials: dto.includesMaterials ?? false,
      inclusionTags: dto.inclusionTags || [],
      hasVoiceNote: dto.hasVoiceNote ?? false,
      voiceDurationSeconds: dto.voiceDurationSeconds || 0,
      voiceTranscriptPreview: dto.voiceTranscriptPreview || null,
      createdAt: new Date().toISOString(),
      status: 'pending',
    };

    // Emitir en tiempo real a todos los clientes suscritos a la sala del trabajo
    this.server.to(room).emit('newBidReceived', bidData);

    this.logger.log(
      `💸 Oferta de S/. ${dto.amount} emitida a sala '${room}' por ${bidData.workerName} (${bidData.workerId})`,
    );

    return {
      success: true,
      message: 'Oferta enviada y transmitida en tiempo real',
      bid: bidData,
    };
  }

  /**
   * Permite contraofertar sobre una oferta en tiempo real.
   * Emite el evento 'counterOfferReceived' a la sala 'job:{jobRequestId}'.
   */
  @SubscribeMessage('counterOffer')
  @UseGuards(WsJwtGuard)
  async handleCounterOffer(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { jobRequestId: string; counterAmount: number; note?: string },
  ) {
    const user = client.data?.user as AuthenticatedUserPayload;
    const room = `job:${payload.jobRequestId}`;

    const counterData = {
      jobRequestId: payload.jobRequestId,
      senderId: user?.sub,
      senderName: user?.fullName || user?.email,
      counterAmount: payload.counterAmount,
      note: payload.note || null,
      timestamp: new Date().toISOString(),
    };

    this.server.to(room).emit('counterOfferReceived', counterData);

    return {
      success: true,
      counterOffer: counterData,
    };
  }

  /**
   * Notifica la aceptación de una oferta a todos en la sala.
   */
  @SubscribeMessage('acceptBid')
  @UseGuards(WsJwtGuard)
  async handleAcceptBid(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { jobRequestId: string; bidId: string; agreedAmount: number },
  ) {
    const user = client.data?.user as AuthenticatedUserPayload;
    const room = `job:${payload.jobRequestId}`;

    const acceptanceData = {
      jobRequestId: payload.jobRequestId,
      bidId: payload.bidId,
      agreedAmount: payload.agreedAmount,
      acceptedBy: user?.sub,
      timestamp: new Date().toISOString(),
    };

    this.server.to(room).emit('bidAccepted', acceptanceData);

    return {
      success: true,
      acceptance: acceptanceData,
    };
  }

  /**
   * Consulta si un usuario específico está online consultando Redis.
   */
  @SubscribeMessage('checkUserOnline')
  async handleCheckUserOnline(@MessageBody() payload: { userId: string }) {
    const isOnline = await this.redisService.isUserOnline(payload.userId);
    return {
      userId: payload.userId,
      isOnline,
    };
  }
}
