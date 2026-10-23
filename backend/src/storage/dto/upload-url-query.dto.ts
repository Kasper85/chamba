import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, Matches } from 'class-validator';

export class UploadUrlQueryDto {
  @ApiPropertyOptional({
    description: 'Nombre del archivo original (ej. foto_fuga.jpg, nota_voz.m4a)',
    example: 'fuga_lavadero.jpg',
  })
  @IsOptional()
  @IsString()
  filename?: string;

  @ApiPropertyOptional({
    description: 'Tipo MIME del archivo a subir (ej. image/jpeg, audio/m4a, video/mp4)',
    example: 'image/jpeg',
    default: 'image/jpeg',
  })
  @IsOptional()
  @IsString()
  contentType?: string = 'image/jpeg';

  @ApiPropertyOptional({
    description: 'Carpeta o contexto de almacenamiento (ej. diagnostics, evidence, audio, avatars)',
    example: 'diagnostics',
    default: 'uploads',
  })
  @IsOptional()
  @IsString()
  @Matches(/^[a-zA-Z0-9_-]+$/, {
    message: 'El nombre de la carpeta solo puede contener caracteres alfanuméricos, guiones o guiones bajos',
  })
  folder?: string = 'uploads';
}
