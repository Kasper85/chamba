import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString, Length } from 'class-validator';
import { JobStatus } from '../../common/job-state-machine.js';

export class UpdateJobPhaseDto {
  @ApiProperty({
    enum: JobStatus,
    description: 'Fase o estado destino de la chamba',
    example: JobStatus.EN_CAMINO,
  })
  @IsEnum(JobStatus, { message: 'Fase o estado inválido' })
  @IsNotEmpty()
  phase: JobStatus;

  @ApiPropertyOptional({
    description: 'PIN de 4 dígitos proporcionado por el cliente para iniciar ejecución',
    example: '4821',
  })
  @IsString()
  @IsOptional()
  @Length(4, 4, { message: 'El PIN debe tener exactamente 4 dígitos' })
  pin?: string;

  @ApiPropertyOptional({
    description: 'URL o identificador de la foto del antes (obligatoria para iniciar ejecución)',
    example: 'https://storage.chamba.pe/jobs/123/before.jpg',
  })
  @IsString()
  @IsOptional()
  photoBefore?: string;

  @ApiPropertyOptional({
    description: 'URL o identificador de la foto del después (obligatoria para finalizar)',
    example: 'https://storage.chamba.pe/jobs/123/after.jpg',
  })
  @IsString()
  @IsOptional()
  photoAfter?: string;
}

