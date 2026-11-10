import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CounterBidDto {
  @ApiProperty({ example: 55.0 })
  @IsNumber()
  @Min(20.0, { message: 'La contraoferta mínima es S/. 20.00' })
  counterAmount: number;

  @ApiPropertyOptional({ example: '¿Podría dejarlo en S/. 55 si pongo los repuestos?' })
  @IsString()
  @IsOptional()
  note?: string;
}

