import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class HoldEscrowDto {
  @ApiProperty({
    example: 'job-101',
    description: 'Identificador único de la solicitud de trabajo asociada al pago retenido',
  })
  @IsNotEmpty({ message: 'El jobRequestId es obligatorio' })
  @IsString()
  jobRequestId: string;

  @ApiProperty({
    example: 75.0,
    description: 'Monto a retener en custodia (Escrow) en soles (S/.)',
  })
  @IsNotEmpty({ message: 'El monto es obligatorio' })
  @Type(() => Number)
  @IsNumber({}, { message: 'El monto debe ser un número válido' })
  @Min(1, { message: 'El monto mínimo a retener es S/. 1.00' })
  amount: number;

  @ApiPropertyOptional({
    example: 'Retención de garantía para gasfitería #job-101',
    description: 'Descripción o nota del movimiento contable',
  })
  @IsOptional()
  @IsString()
  description?: string;
}
