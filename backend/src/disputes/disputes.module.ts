import { Module } from '@nestjs/common';
import { DisputesController } from './disputes.controller.js';
import { DisputesService } from './disputes.service.js';
import { PrismaModule } from '../prisma/prisma.module.js';
import { FinanceModule } from '../finance/finance.module.js';
import { EventsModule } from '../events/events.module.js';

@Module({
  imports: [PrismaModule, FinanceModule, EventsModule],
  controllers: [DisputesController],
  providers: [DisputesService],
  exports: [DisputesService],
})
export class DisputesModule {}

