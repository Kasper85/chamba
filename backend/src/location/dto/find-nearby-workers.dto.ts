import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class FindNearbyWorkersDto {
  @ApiProperty({
    example: -6.7725,
    description: 'Latitud del punto de búsqueda GPS (sistema WGS 84, entre -90 y 90)',
  })
  @Type(() => Number)
  @IsNumber({}, { message: 'La latitud (lat) debe ser un número decimal válido' })
  @Min(-90, { message: 'La latitud no puede ser menor a -90' })
  @Max(90, { message: 'La latitud no puede ser mayor a 90' })
  lat: number;

  @ApiProperty({
    example: -79.8398,
    description: 'Longitud del punto de búsqueda GPS (sistema WGS 84, entre -180 y 180)',
  })
  @Type(() => Number)
  @IsNumber({}, { message: 'La longitud (lng) debe ser un número decimal válido' })
  @Min(-180, { message: 'La longitud no puede ser menor a -180' })
  @Max(180, { message: 'La longitud no puede ser mayor a 180' })
  lng: number;

  @ApiPropertyOptional({
    example: 5,
    default: 5,
    description: 'Radio de búsqueda en kilómetros (por defecto 5 km, rango 0.1 a 100 km)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({}, { message: 'El radio en kilómetros (radiusKm) debe ser un número válido' })
  @Min(0.1, { message: 'El radio mínimo de búsqueda es 0.1 km (100 metros)' })
  @Max(100, { message: 'El radio máximo de búsqueda es 100 km' })
  radiusKm?: number = 5;

  @ApiPropertyOptional({
    example: 'Gasfitería',
    description: 'Filtro opcional por especialidad del técnico (ej. Gasfitería, Electricidad, Cerrajería)',
  })
  @IsOptional()
  @IsString()
  specialty?: string;
}
