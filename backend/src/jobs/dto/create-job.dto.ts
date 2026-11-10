import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateJobDto {
  @ApiProperty({ example: 'Fuga de agua en lavadero de cocina' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ example: 'El tubo debajo del fregadero gotea constantemente y requiere cambio de empaque.' })
  @IsString()
  @IsNotEmpty()
  description: string;

  @ApiProperty({ example: 'gasfiteria' })
  @IsString()
  @IsNotEmpty()
  category: string;

  @ApiProperty({ example: 60.0 })
  @IsNumber()
  @Min(20.0, { message: 'El presupuesto mínimo en CHAMBA es S/. 20.00' })
  budget: number;

  @ApiProperty({ example: 'Chiclayo' })
  @IsString()
  @IsNotEmpty()
  district: string;

  @ApiPropertyOptional({ example: 'Calle San José 450, Dpto 3B' })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiPropertyOptional({ example: 'Frente al parque principal' })
  @IsString()
  @IsOptional()
  reference?: string;

  @ApiPropertyOptional({ example: -6.7725 })
  @IsNumber()
  @IsOptional()
  latitude?: number;

  @ApiPropertyOptional({ example: -79.8398 })
  @IsNumber()
  @IsOptional()
  longitude?: number;

  @ApiPropertyOptional({ example: false })
  @IsBoolean()
  @IsOptional()
  isSos?: boolean;

  @ApiPropertyOptional({ example: 'MEDIA' })
  @IsString()
  @IsOptional()
  urgency?: string;
}

