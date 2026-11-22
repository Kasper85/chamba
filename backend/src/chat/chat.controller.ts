import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { IsNotEmpty, IsString, MaxLength, IsArray, ArrayMaxSize, IsOptional, IsInt, Min, Max, Matches } from 'class-validator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { ChatService } from './chat.service.js';

class SendMessageDto {
  @IsString() @IsNotEmpty() @MaxLength(100) clientMessageId: string;
  @IsString() @IsNotEmpty() @MaxLength(4000) text: string;
  @IsOptional() @IsString() @MaxLength(280000) @Matches(/^[A-Za-z0-9+/]+=*$/) audioBase64?: string;
  @IsOptional() @IsInt() @Min(1) @Max(30) audioDurationSeconds?: number;
}
class DeliveredMessagesDto {
  @IsArray() @ArrayMaxSize(500) @IsString({ each: true }) messageIds: string[];
}

@Controller('jobs/:jobId/messages')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(private readonly chat: ChatService) {}
  @Get()
  list(@Param('jobId') jobId: string, @CurrentUser() user: { id: string }) {
    return this.chat.list(jobId, user.id);
  }
  @Post()
  send(@Param('jobId') jobId: string, @CurrentUser() user: { id: string }, @Body() dto: SendMessageDto) {
    return this.chat.send(jobId, user.id, dto.clientMessageId, dto.text, dto.audioBase64, dto.audioDurationSeconds);
  }
  @Post('delivered')
  delivered(@Param('jobId') jobId: string, @CurrentUser() user: { id: string }, @Body() dto: DeliveredMessagesDto) {
    return this.chat.delivered(jobId, user.id, dto.messageIds);
  }
}
