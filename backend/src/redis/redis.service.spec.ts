import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { RedisService } from './redis.service.js';

describe('RedisService (Unit Tests)', () => {
  let service: RedisService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RedisService,
        {
          provide: ConfigService,
          useValue: {
            get: vi.fn().mockReturnValue('redis://localhost:6379'),
          },
        },
      ],
    }).compile();

    service = module.get<RedisService>(RedisService);
    // Inicializar (en modo fallback en memoria si redis local no está encendido)
    await service.onModuleInit();
  });

  afterEach(async () => {
    await service.onModuleDestroy();
  });

  describe('Manejo de estado de conexión efímero (User Online/Offline)', () => {
    it('debe marcar a un usuario como online al conectar un socket', async () => {
      const userId = 'user-test-123';
      const socketId = 'socket-abc-1';

      expect(await service.isUserOnline(userId)).toBe(false);

      await service.setUserOnline(userId, socketId);

      expect(await service.isUserOnline(userId)).toBe(true);
      const sockets = await service.getUserSockets(userId);
      expect(sockets).toContain(socketId);
    });

    it('debe mantener al usuario online si tiene múltiples sockets abiertos (p. ej. móvil y web)', async () => {
      const userId = 'user-multi-device';
      const socketMobile = 'socket-mobile-1';
      const socketWeb = 'socket-web-2';

      await service.setUserOnline(userId, socketMobile);
      await service.setUserOnline(userId, socketWeb);

      expect(await service.isUserOnline(userId)).toBe(true);
      expect(await service.getUserSockets(userId)).toHaveLength(2);

      // Desconectar móvil: el usuario sigue online por la sesión web
      await service.setUserOffline(userId, socketMobile);
      expect(await service.isUserOnline(userId)).toBe(true);

      // Desconectar web: ahora pasa a offline
      await service.setUserOffline(userId, socketWeb);
      expect(await service.isUserOnline(userId)).toBe(false);
      expect(await service.getUserSockets(userId)).toHaveLength(0);
    });
  });
});
