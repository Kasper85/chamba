import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class UpdateWorkerLocationDto {
  @ApiProperty({
    example: -6.7725,
    description: 'Latitud GPS (coordenada Y en sistema WGS 84, entre -90 y 90 grados)',
  })
  @IsNotEmpty({ message: 'La latitud es obligatoria' })
  @Type(() => Number)
  @IsNumber({}, { message: 'La latitud debe ser un número decimal válido' })
  @Min(-90, { message: 'La latitud mínima permitida es -90' })
  @Max(90, { message: 'La latitud máxima permitida es 90' })
  latitude: number;

  @ApiProperty({
    example: -79.8398,
    description: 'Longitud GPS (coordenada X en sistema WGS 84, entre -180 y 180 grados)',
  })
  @IsNotEmpty({ message: 'La longitud es obligatoria' })
  @Type(() => Number)
  @IsNumber({}, { message: 'La longitud debe ser un número decimal válido' })
  @Min(-180, { message: 'La longitud mínima permitida es -180' })
  @Max(180, { message: 'La longitud máxima permitida es 180' })
  longitude: number;
}
