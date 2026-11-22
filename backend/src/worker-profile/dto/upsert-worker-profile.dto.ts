import { IsBoolean, IsOptional, IsString, Matches, IsNumber, IsInt, Min, Max, IsArray, ArrayMaxSize, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UpsertWorkerProfileDto {
  @IsOptional() @IsString() @Matches(/^(\d{8})?$/) dni?: string;
  @IsOptional() @IsNumber() @Min(0) @Max(100000) baseRate?: number;
  @IsOptional() @IsInt() @Min(0) @Max(500) serviceRadiusKm?: number;
  @IsOptional() @IsInt() @Min(0) @Max(80) experienceYears?: number;
  @IsOptional() @IsArray() @ArrayMaxSize(20) @IsString({ each: true }) @MaxLength(100, { each: true }) skills?: string[];
  @ApiProperty({ example: 'Electricista matriculado y técnico en mantenimiento del hogar con 8 años de experiencia.', description: 'Descripción o bio profesional' })
  @IsString()
  @MaxLength(2000)
  bio: string;

  @ApiPropertyOptional({ example: 'Santa Victoria, Chiclayo', description: 'Distrito principal de cobertura' })
  @IsOptional()
  @IsString()
  district?: string;

  @ApiProperty({ example: 'Electricidad', description: 'Especialidad u oficio principal' })
  @IsString()
  @MaxLength(100)
  specialty: string;

  @ApiPropertyOptional({ example: true, description: 'Disponibilidad para recibir solicitudes' })
  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;
}
