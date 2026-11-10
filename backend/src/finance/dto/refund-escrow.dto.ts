import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsUUID } from 'class-validator';

export class RefundEscrowDto {
  @ApiProperty({ description: 'ID de la solicitud de trabajo' })
  @IsUUID()
  jobRequestId: string;

  @ApiProperty({
    description: 'Indica si el técnico ya estaba en camino al momento de la cancelación',
    required: false,
    default: false,
  })
  @IsBoolean()
  @IsOptional()
  isWorkerOnTheWay?: boolean;

  @ApiProperty({
    description: 'ID de usuario del técnico para acreditar la compensación si estaba en camino',
    required: false,
  })
  @IsUUID()
  @IsOptional()
  workerUserId?: string;
}

