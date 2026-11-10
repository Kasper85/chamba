import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Socket } from 'socket.io';
import { EventsGateway } from './events.gateway.js';
import { RedisService } from '../redis/redis.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

describe('EventsGateway (Unit Tests)', () => {
  let gateway: EventsGateway;
  let jwtService: JwtService;
  let redisService: RedisService;

  const mockServer = {
    to: vi.fn().mockReturnThis(),
    emit: vi.fn(),
  };

  const mockJwtService = {
    verify: vi.fn(),
  };

  const mockRedisService = {
    setUserOnline: vi.fn(),
    setUserOffline: vi.fn(),
    isUserOnline: vi.fn(),
    getUserSockets: vi.fn(),
  };

  const mockConfigService = {
    get: vi.fn().mockReturnValue('mock-jwt-secret'),
  };

  beforeEach(async () => {
    vi.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        EventsGateway,
        { provide: JwtService, useValue: mockJwtService },
        { provide: RedisService, useValue: mockRedisService },
        { provide: ConfigService, useValue: mockConfigService },
      ],
    }).compile();

    gateway = module.get<EventsGateway>(EventsGateway);
    jwtService = module.get<JwtService>(JwtService);
    redisService = module.get<RedisService>(RedisService);

    // Asignar el mock server a la propiedad del gateway
    gateway.server = mockServer as any;
  });

  describe('Autenticación y Conexión de Sockets (handleConnection & handleDisconnect)', () => {
    it('debe autenticar al usuario por JWT, unirlo a su sala y guardarlo online en Redis', async () => {
      const mockPayload = {
        sub: 'user-worker-101',
        email: 'jorge.quispe@chamba.pe',
        fullName: 'Jorge Quispe Baldera',
      };
      mockJwtService.verify.mockReturnValue(mockPayload);

      const mockSocket = {
        id: 'socket-test-1',
        handshake: {
          auth: { token: 'valid-jwt-token' },
          headers: {},
        },
        data: {},
        join: vi.fn().mockResolvedValue(undefined),
        disconnect: vi.fn(),
      } as unknown as Socket;

      await gateway.handleConnection(mockSocket);

      expect(jwtService.verify).toHaveBeenCalledWith('valid-jwt-token', { secret: 'mock-jwt-secret' });
      expect(mockSocket.data.user).toEqual(mockPayload);
      expect(redisService.setUserOnline).toHaveBeenCalledWith('user-worker-101', 'socket-test-1');
      expect(mockSocket.join).toHaveBeenCalledWith('user:user-worker-101');
      expect(mockSocket.disconnect).not.toHaveBeenCalled();
    });

    it('debe rechazar y desconectar el socket si no se proporciona token', async () => {
      const mockSocket = {
        id: 'socket-unauth',
        handshake: {
          auth: {},
          headers: {},
        },
        disconnect: vi.fn(),
      } as unknown as Socket;

      await gateway.handleConnection(mockSocket);

      expect(mockSocket.disconnect).toHaveBeenCalledWith(true);
      expect(redisService.setUserOnline).not.toHaveBeenCalled();
    });

    it('debe actualizar el estado en Redis a offline cuando el socket se desconecta', async () => {
      const mockSocket = {
        id: 'socket-disconnect-1',
        data: {
          user: { sub: 'user-worker-101' },
        },
      } as unknown as Socket;

      await gateway.handleDisconnect(mockSocket);

      expect(redisService.setUserOffline).toHaveBeenCalledWith('user-worker-101', 'socket-disconnect-1');
    });
  });

  describe('Salas de Trabajo (joinJobRoom & leaveJobRoom)', () => {
    it('debe unir al socket a la sala del trabajo correspondiente', async () => {
      const mockSocket = {
        id: 'socket-client-1',
        join: vi.fn().mockResolvedValue(undefined),
        emit: vi.fn(),
      } as unknown as Socket;

      const result = await gateway.handleJoinJobRoom(mockSocket, { jobRequestId: 'job-555' });

      expect(mockSocket.join).toHaveBeenCalledWith('job:job-555');
      expect(mockSocket.emit).toHaveBeenCalledWith('joinedJobRoom', expect.objectContaining({ room: 'job:job-555' }));
      expect(result.success).toBe(true);
      expect(result.room).toBe('job:job-555');
    });

    it('debe retirar al socket de la sala del trabajo', async () => {
      const mockSocket = {
        id: 'socket-client-1',
        leave: vi.fn().mockResolvedValue(undefined),
        emit: vi.fn(),
      } as unknown as Socket;

      const result = await gateway.handleLeaveJobRoom(mockSocket, { jobRequestId: 'job-555' });

      expect(mockSocket.leave).toHaveBeenCalledWith('job:job-555');
      expect(mockSocket.emit).toHaveBeenCalledWith('leftJobRoom', expect.objectContaining({ jobRequestId: 'job-555' }));
      expect(result.success).toBe(true);
    });
  });

  describe('Flujo de Ofertas en Tiempo Real (sendBid)', () => {
    it('debe emitir el evento newBidReceived a la sala específica del trabajo', async () => {
      const mockSocket = {
        id: 'socket-worker-bid',
        data: {
          user: {
            sub: 'worker-jorge',
            fullName: 'Jorge Quispe Baldera',
            email: 'jorge@chamba.pe',
          },
        },
      } as unknown as Socket;

      const bidDto = {
        jobRequestId: 'job-777',
        amount: 65.0,
        message: 'Tengo materiales listos',
        estimatedArrival: '15 min',
        includesMaterials: true,
        inclusionTags: ['Incluye materiales', 'Llego en < 20 min'],
        hasVoiceNote: true,
        voiceDurationSeconds: 12,
        voiceTranscriptPreview: 'Buenas tardes, voy con repuesto de 1/2 pulgada',
      };

      const result = await gateway.handleSendBid(mockSocket, bidDto);

      expect(mockServer.to).toHaveBeenCalledWith('job:job-777');
      expect(mockServer.emit).toHaveBeenCalledWith(
        'newBidReceived',
        expect.objectContaining({
          jobRequestId: 'job-777',
          workerId: 'worker-jorge',
          workerName: 'Jorge Quispe Baldera',
          amount: 65.0,
          estimatedArrival: '15 min',
          includesMaterials: true,
          hasVoiceNote: true,
        }),
      );

      expect(result.success).toBe(true);
      expect(result.bid.amount).toBe(65.0);
    });
  });

  describe('Negociación en tiempo real (counterOffer & acceptBid)', () => {
    it('debe emitir counterOfferReceived a la sala job:{jobRequestId}', async () => {
      const mockSocket = {
        id: 'socket-client-counter',
        data: {
          user: { sub: 'client-lucia', fullName: 'Lucía Fernández' },
        },
      } as unknown as Socket;

      const payload = {
        jobRequestId: 'job-777',
        counterAmount: 55.0,
        note: '¿Lo cerramos en 55?',
      };

      const result = await gateway.handleCounterOffer(mockSocket, payload);

      expect(mockServer.to).toHaveBeenCalledWith('job:job-777');
      expect(mockServer.emit).toHaveBeenCalledWith(
        'counterOfferReceived',
        expect.objectContaining({
          jobRequestId: 'job-777',
          counterAmount: 55.0,
          senderId: 'client-lucia',
        }),
      );
      expect(result.success).toBe(true);
    });

    it('debe emitir bidAccepted a la sala al aceptar la oferta', async () => {
      const mockSocket = {
        id: 'socket-client-accept',
        data: {
          user: { sub: 'client-lucia' },
        },
      } as unknown as Socket;

      const payload = {
        jobRequestId: 'job-777',
        bidId: 'bid-123',
        agreedAmount: 60.0,
      };

      const result = await gateway.handleAcceptBid(mockSocket, payload);

      expect(mockServer.to).toHaveBeenCalledWith('job:job-777');
      expect(mockServer.emit).toHaveBeenCalledWith(
        'bidAccepted',
        expect.objectContaining({
          jobRequestId: 'job-777',
          agreedAmount: 60.0,
          bidId: 'bid-123',
        }),
      );
      expect(result.success).toBe(true);
    });
  });

  describe('Control de acceso a salas y eventos de negociación (ALCANCE.md §8 L14)', () => {
    let secureGateway: EventsGateway;
    const mockPrisma = {
      jobRequest: {
        findUnique: vi.fn(),
      },
      workerProfile: {
        findUnique: vi.fn(),
      },
    };

    beforeEach(async () => {
      const module: TestingModule = await Test.createTestingModule({
        providers: [
          EventsGateway,
          { provide: JwtService, useValue: mockJwtService },
          { provide: RedisService, useValue: mockRedisService },
          { provide: ConfigService, useValue: mockConfigService },
          { provide: PrismaService, useValue: mockPrisma },
        ],
      }).compile();

      secureGateway = module.get<EventsGateway>(EventsGateway);
      secureGateway.server = mockServer as any;
    });

    it('debe rechazar unirse a la sala si un usuario común sin perfil de técnico intenta entrar en BUSCANDO', async () => {
      mockPrisma.jobRequest.findUnique.mockResolvedValue({
        id: 'job-999',
        clientId: 'client-1',
        status: 'BUSCANDO',
      });
      mockPrisma.workerProfile.findUnique.mockResolvedValue(null);

      const mockSocket = {
        id: 'socket-stranger',
        data: { user: { sub: 'stranger-user', role: 'CLIENT' } },
        join: vi.fn(),
        emit: vi.fn(),
      } as unknown as Socket;

      const result = await secureGateway.handleJoinJobRoom(mockSocket, { jobRequestId: 'job-999' });

      expect(result.success).toBe(false);
      expect(mockSocket.join).not.toHaveBeenCalled();
      expect(mockSocket.emit).toHaveBeenCalledWith('error', expect.objectContaining({ message: expect.any(String) }));
    });

    it('debe rechazar si un técnico no asignado intenta entrar en fase EN_CAMINO/EN_EJECUCION', async () => {
      mockPrisma.jobRequest.findUnique.mockResolvedValue({
        id: 'job-999',
        clientId: 'client-1',
        workerId: 'assigned-worker-prof',
        status: 'EN_CAMINO',
        worker: { user: { id: 'assigned-worker-user' } },
      });

      const mockSocket = {
        id: 'socket-unrelated-worker',
        data: { user: { sub: 'other-worker-user', role: 'WORKER' } },
        join: vi.fn(),
        emit: vi.fn(),
      } as unknown as Socket;

      const result = await secureGateway.handleJoinJobRoom(mockSocket, { jobRequestId: 'job-999' });

      expect(result.success).toBe(false);
      expect(mockSocket.join).not.toHaveBeenCalled();
      expect(mockSocket.emit).toHaveBeenCalledWith('error', expect.objectContaining({ message: expect.any(String) }));
    });

    it('debe permitir al cliente de la chamba unirse a la sala', async () => {
      mockPrisma.jobRequest.findUnique.mockResolvedValue({
        id: 'job-999',
        clientId: 'client-1',
        status: 'EN_CAMINO',
        worker: { user: { id: 'assigned-worker-user' } },
      });

      const mockSocket = {
        id: 'socket-client',
        data: { user: { sub: 'client-1', role: 'CLIENT' } },
        join: vi.fn().mockResolvedValue(undefined),
        emit: vi.fn(),
      } as unknown as Socket;

      const result = await secureGateway.handleJoinJobRoom(mockSocket, { jobRequestId: 'job-999' });

      expect(result.success).toBe(true);
      expect(mockSocket.join).toHaveBeenCalledWith('job:job-999');
    });

    it('debe rechazar acceptBid si quien emite el evento no es el cliente', async () => {
      mockPrisma.jobRequest.findUnique.mockResolvedValue({
        id: 'job-999',
        clientId: 'client-1',
      });

      const mockSocket = {
        id: 'socket-impostor',
        data: { user: { sub: 'impostor-user' } },
        emit: vi.fn(),
      } as unknown as Socket;

      const result = await secureGateway.handleAcceptBid(mockSocket, {
        jobRequestId: 'job-999',
        bidId: 'bid-1',
        agreedAmount: 50.0,
      });

      expect(result.success).toBe(false);
      expect(mockSocket.emit).toHaveBeenCalledWith('error', expect.objectContaining({ message: expect.any(String) }));
    });
  });
});
