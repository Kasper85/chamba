import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class ReleaseEscrowDto {
  @ApiProperty({
    example: 'job-101',
    description: 'Identificador único de la solicitud de trabajo completada',
  })
  @IsNotEmpty({ message: 'El jobRequestId es obligatorio' })
  @IsString()
  jobRequestId: string;

  @ApiProperty({
    example: 'user-worker-101',
    description: 'ID de usuario del técnico que completó el servicio y recibirá los fondos',
  })
  @IsNotEmpty({ message: 'El workerUserId es obligatorio' })
  @IsString()
  workerUserId: string;

  @ApiPropertyOptional({
    example: 75.0,
    description: 'Monto específico a liberar (si se omite, se libera el monto total retenido)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({}, { message: 'El monto debe ser un número válido' })
  @Min(1, { message: 'El monto mínimo a liberar es S/. 1.00' })
  amount?: number;
}
