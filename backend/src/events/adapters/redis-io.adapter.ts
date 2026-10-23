import { IoAdapter } from '@nestjs/platform-socket.io';
import { ServerOptions } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient } from 'redis';
import { Logger } from '@nestjs/common';

export class RedisIoAdapter extends IoAdapter {
  protected override readonly logger = new Logger(RedisIoAdapter.name);
  private adapterConstructor: ReturnType<typeof createAdapter> | null = null;

  async connectToRedis(customUrl?: string): Promise<void> {
    const redisUrl = customUrl || process.env.REDIS_URL || 'redis://localhost:6379';

    try {
      const pubClient = createClient({
        url: redisUrl,
        socket: {
          reconnectStrategy: (retries: number) => {
            if (retries > 2) {
              return false; // No reintentar indefinidamente si Redis no está levantado
            }
            return 500;
          },
        },
      });
      const subClient = pubClient.duplicate();

      pubClient.on('error', (err) => {
        this.logger.debug(`Redis Pub client error: ${err?.message || err}`);
      });
      subClient.on('error', (err) => {
        this.logger.debug(`Redis Sub client error: ${err?.message || err}`);
      });

      await Promise.all([pubClient.connect(), subClient.connect()]);
      this.adapterConstructor = createAdapter(pubClient, subClient);
      this.logger.log(`⚡ RedisIoAdapter conectado exitosamente a Redis Pub/Sub (${redisUrl})`);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      this.adapterConstructor = null;
      this.logger.warn(
        `⚠️ RedisIoAdapter no pudo conectar a Redis (${message}). Continuando con In-Memory Adapter de Socket.IO.`,
      );
    }
  }

  override createIOServer(port: number, options?: ServerOptions) {
    const server = super.createIOServer(port, options);

    if (this.adapterConstructor) {
      server.adapter(this.adapterConstructor);
      this.logger.log('📡 Adaptador Redis Pub/Sub montado en servidor Socket.IO');
    }

    return server;
  }
}
