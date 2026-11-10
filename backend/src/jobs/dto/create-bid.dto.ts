import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateBidDto {
  @ApiProperty({ example: 65.0 })
  @IsNumber()
  @Min(20.0, { message: 'La oferta mínima es S/. 20.00' })
  amount: number;

  @ApiPropertyOptional({ example: 'Llego en 20 minutos con herramientas completas' })
  @IsString()
  @IsOptional()
  message?: string;

  @ApiPropertyOptional({ example: 25 })
  @IsInt()
  @IsOptional()
  estimatedEtaMinutes?: number;

  @ApiPropertyOptional({ example: 'https://storage.chamba.pe/voice/bid-123.m4a' })
  @IsString()
  @IsOptional()
  voiceNoteUrl?: string;
}

