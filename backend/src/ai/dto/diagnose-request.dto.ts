import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class DiagnoseRequestDto {
  @ApiProperty({
    description: 'URL o clave del archivo multimedia subido previamente a Cloudflare R2 / S3',
    example: 'https://pub-chamba.r2.dev/diagnostics/fuga_lavadero.jpg',
  })
  @IsString()
  imageUrl: string;

  @ApiPropertyOptional({
    description: 'Texto breve con la descripción del problema o notas del cliente',
    example: 'Tubería goteando bajo el lavadero de la cocina desde ayer en la noche.',
  })
  @IsOptional()
  @IsString()
  prompt?: string;
}
