import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class DepositWalletDto {
  @ApiProperty({
    example: 100.0,
    description: 'Monto a recargar en la billetera en soles (S/.)',
  })
  @IsNotEmpty({ message: 'El monto es obligatorio' })
  @Type(() => Number)
  @IsNumber({}, { message: 'El monto debe ser un número válido' })
  @Min(1, { message: 'El monto mínimo de depósito es S/. 1.00' })
  amount: number;

  @ApiPropertyOptional({
    example: 'Recarga vía Yape / Plin',
    description: 'Descripción del depósito o referencia externa',
  })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({
    example: 'job-101',
    description: 'Solicitud de trabajo opcional a la que se destinará el saldo',
  })
  @IsOptional()
  @IsString()
  jobRequestId?: string;
}
