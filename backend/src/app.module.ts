import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module.js';
import { AuthModule } from './auth/auth.module.js';
import { UsersModule } from './users/users.module.js';
import { WorkerProfileModule } from './worker-profile/worker-profile.module.js';
import { LocationModule } from './location/location.module.js';
import { RedisModule } from './redis/redis.module.js';
import { EventsModule } from './events/events.module.js';
import { FinanceModule } from './finance/finance.module.js';
import { StorageModule } from './storage/storage.module.js';
import { AiModule } from './ai/ai.module.js';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    PrismaModule,
    RedisModule,
    EventsModule,
    FinanceModule,
    StorageModule,
    AiModule,
    AuthModule,
    UsersModule,
    WorkerProfileModule,
    LocationModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
