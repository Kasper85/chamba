import { IsBoolean, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UpsertWorkerProfileDto {
  @ApiProperty({ example: 'Electricista matriculado y técnico en mantenimiento del hogar con 8 años de experiencia.', description: 'Descripción o bio profesional' })
  @IsString()
  @IsNotEmpty({ message: 'La descripción profesional es obligatoria' })
  bio: string;

  @ApiPropertyOptional({ example: 'Santa Victoria, Chiclayo', description: 'Distrito principal de cobertura' })
  @IsOptional()
  @IsString()
  district?: string;

  @ApiProperty({ example: 'Electricidad', description: 'Especialidad u oficio principal' })
  @IsString()
  @IsNotEmpty({ message: 'La especialidad inicial es obligatoria' })
  specialty: string;

  @ApiPropertyOptional({ example: true, description: 'Disponibilidad para recibir solicitudes' })
  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;
}
