import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { FinanceService } from './finance.service.js';
import { FinanceController } from './finance.controller.js';
import { WebhooksController } from './webhooks.controller.js';
import { PrismaModule } from '../prisma/prisma.module.js';

@Module({
  imports: [PrismaModule, ConfigModule],
  controllers: [FinanceController, WebhooksController],
  providers: [FinanceService],
  exports: [FinanceService],
})
export class FinanceModule {}
