import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, RedisClientType } from 'redis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: RedisClientType | null = null;
  private isConnected = false;

  // Fallback en memoria si Redis no está activo localmente durante desarrollo o pruebas
  private readonly inMemoryOnlineUsers = new Map<string, Set<string>>();

  constructor(private readonly configService: ConfigService) {}

  async onModuleInit(): Promise<void> {
    const redisUrl = this.configService.get<string>('REDIS_URL', 'redis://localhost:6379');

    try {
      this.client = createClient({
        url: redisUrl,
        socket: {
          reconnectStrategy: (retries: number) => {
            if (retries > 3) {
              this.logger.warn('⚠️ Se superó el límite de reintentos con Redis. Operando en modo memoria.');
              return false;
            }
            return Math.min(retries * 200, 1000);
          },
        },
      });

      this.client.on('error', (err) => {
        this.logger.debug(`Redis client status: ${err?.message || err}`);
      });

      await this.client.connect();
      this.isConnected = true;
      this.logger.log(`🔴 Conectado a Redis exitosamente en: ${redisUrl}`);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      this.isConnected = false;
      this.logger.warn(`⚠️ Redis no disponible (${message}). Fallback en memoria activado para sesiones.`);
    }
  }

  async onModuleDestroy(): Promise<void> {
    if (this.client && this.isConnected) {
      try {
        await this.client.quit();
      } catch {
        // Disconnect silencioso al apagar
      }
    }
  }

  getClient(): RedisClientType | null {
    return this.isConnected ? this.client : null;
  }

  /**
   * Registra la conexión de un usuario (cliente o técnico) como online.
   * Guarda una clave efímera 'user:online:{userId}' y agrega el socketId al set 'user:sockets:{userId}'.
   */
  async setUserOnline(userId: string, socketId: string, ttlSeconds = 86400): Promise<void> {
    if (this.isConnected && this.client) {
      const multi = this.client.multi();
      multi.set(`user:online:${userId}`, 'true', { EX: ttlSeconds });
      multi.sAdd(`user:sockets:${userId}`, socketId);
      multi.expire(`user:sockets:${userId}`, ttlSeconds);
      await multi.exec();
    } else {
      if (!this.inMemoryOnlineUsers.has(userId)) {
        this.inMemoryOnlineUsers.set(userId, new Set<string>());
      }
      this.inMemoryOnlineUsers.get(userId)?.add(socketId);
    }
  }

  /**
   * Remueve el socketId al desconectarse el usuario.
   * Si no quedan sockets activos para ese usuario, se elimina la clave de estado online.
   */
  async setUserOffline(userId: string, socketId: string): Promise<void> {
    if (this.isConnected && this.client) {
      await this.client.sRem(`user:sockets:${userId}`, socketId);
      const remainingSockets = await this.client.sCard(`user:sockets:${userId}`);
      if (remainingSockets === 0) {
        await this.client.del(`user:online:${userId}`);
        await this.client.del(`user:sockets:${userId}`);
      }
    } else {
      const sockets = this.inMemoryOnlineUsers.get(userId);
      if (sockets) {
        sockets.delete(socketId);
        if (sockets.size === 0) {
          this.inMemoryOnlineUsers.delete(userId);
        }
      }
    }
  }

  /**
   * Verifica si un usuario está en línea en este momento.
   */
  async isUserOnline(userId: string): Promise<boolean> {
    if (this.isConnected && this.client) {
      const exists = await this.client.exists(`user:online:${userId}`);
      return exists === 1;
    }
    const sockets = this.inMemoryOnlineUsers.get(userId);
    return Boolean(sockets && sockets.size > 0);
  }

  /**
   * Obtiene todos los IDs de socket activos asociados a un usuario.
   */
  async getUserSockets(userId: string): Promise<string[]> {
    if (this.isConnected && this.client) {
      return this.client.sMembers(`user:sockets:${userId}`);
    }
    const sockets = this.inMemoryOnlineUsers.get(userId);
    return sockets ? Array.from(sockets) : [];
  }
}
