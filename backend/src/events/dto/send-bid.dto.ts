import { IsArray, IsBoolean, IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class SendBidDto {
  @IsNotEmpty({ message: 'El ID de la solicitud (jobRequestId) es obligatorio' })
  @IsString()
  jobRequestId: string;

  @IsNotEmpty({ message: 'El monto de la oferta (amount) es obligatorio' })
  @Type(() => Number)
  @IsNumber({}, { message: 'El monto debe ser un número válido' })
  @Min(1, { message: 'El monto mínimo de oferta es S/. 1' })
  amount: number;

  @IsOptional()
  @IsString()
  message?: string;

  @IsOptional()
  @IsString()
  estimatedArrival?: string;

  @IsOptional()
  @IsBoolean()
  includesMaterials?: boolean;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  inclusionTags?: string[];

  @IsOptional()
  @IsBoolean()
  hasVoiceNote?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  voiceDurationSeconds?: number;

  @IsOptional()
  @IsString()
  voiceTranscriptPreview?: string;
}
