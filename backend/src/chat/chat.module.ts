import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module.js';
import { ChatService } from './chat.service.js';
import { ChatController } from './chat.controller.js';

@Module({ imports: [PrismaModule], providers: [ChatService], controllers: [ChatController] })
export class ChatModule {}
