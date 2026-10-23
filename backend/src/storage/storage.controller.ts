import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { StorageService } from './storage.service.js';
import { UploadUrlQueryDto } from './dto/upload-url-query.dto.js';

@ApiTags('Storage (Cloudflare R2 / S3)')
@Controller('storage')
export class StorageController {
  constructor(private readonly storageService: StorageService) {}

  @Get('upload-url')
  @ApiOperation({
    summary: 'Generar URL prefirmada (Presigned URL) para subida directa a Cloudflare R2',
    description:
      'Permite a la aplicación Flutter subir fotos o notas de voz directamente al almacenamiento seguro sin saturar el backend.',
  })
  @ApiResponse({
    status: 200,
    description: 'URL prefirmada generada exitosamente con expiración de 15 minutos',
    schema: {
      example: {
        uploadUrl: 'https://chamba-uploads.chamba-r2-account.r2.cloudflarestorage.com/diagnostics/uuid-fuga.jpg?...',
        fileKey: 'diagnostics/4f8b9e12-fuga.jpg',
        publicUrl: 'https://pub-chamba.r2.dev/diagnostics/4f8b9e12-fuga.jpg',
        expiresIn: 900,
        contentType: 'image/jpeg',
      },
    },
  })
  @ApiResponse({ status: 500, description: 'Error interno al generar la firma criptográfica' })
  async getUploadUrl(@Query() query: UploadUrlQueryDto) {
    return this.storageService.createPresignedUploadUrl(query);
  }
}
