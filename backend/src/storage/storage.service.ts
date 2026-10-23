import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'node:crypto';
import { UploadUrlQueryDto } from './dto/upload-url-query.dto.js';

export interface PresignedUploadUrlResponse {
  uploadUrl: string;
  fileKey: string;
  publicUrl: string;
  expiresIn: number;
  contentType: string;
}

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly s3Client: S3Client;
  private readonly bucketName: string;
  private readonly publicUrlBase?: string;
  private readonly endpoint: string;

  constructor(private readonly configService: ConfigService) {
    const accountId = this.configService.get<string>('R2_ACCOUNT_ID', 'chamba-r2-account');
    const accessKeyId = this.configService.get<string>('R2_ACCESS_KEY_ID', 'mock-access-key');
    const secretAccessKey = this.configService.get<string>('R2_SECRET_ACCESS_KEY', 'mock-secret-key');
    this.bucketName = this.configService.get<string>('R2_BUCKET_NAME', 'chamba-uploads');
    this.publicUrlBase = this.configService.get<string>('R2_PUBLIC_URL');

    const customEndpoint = this.configService.get<string>('R2_ENDPOINT');
    this.endpoint = customEndpoint || `https://${accountId}.r2.cloudflarestorage.com`;

    this.s3Client = new S3Client({
      region: 'auto',
      endpoint: this.endpoint,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
      forcePathStyle: true,
    });

    this.logger.log(
      `StorageService inicializado con endpoint: ${this.endpoint}, bucket: ${this.bucketName}`,
    );
  }

  /**
   * Genera una URL prefirmada (Presigned URL) para que la app cliente suba
   * archivos multimedia (fotos de diagnóstico, audios de averías) directamente a R2/S3.
   */
  async createPresignedUploadUrl(query: UploadUrlQueryDto): Promise<PresignedUploadUrlResponse> {
    const folder = (query.folder || 'uploads').trim();
    const contentType = (query.contentType || 'image/jpeg').trim();
    const rawFilename = query.filename || 'media.jpg';

    // Sanitizar nombre de archivo previniendo directory traversal y caracteres peligrosos
    const parsedExt = rawFilename.includes('.') ? rawFilename.slice(rawFilename.lastIndexOf('.')) : '';
    const safeExt = parsedExt.toLowerCase().replace(/[^a-z0-9.]/g, '');
    const rawBase = rawFilename.includes('.')
      ? rawFilename.slice(0, rawFilename.lastIndexOf('.'))
      : rawFilename;
    const safeBase = rawBase
      .toLowerCase()
      .replace(/[^a-z0-9_-]/g, '_')
      .replace(/_{2,}/g, '_')
      .replace(/^_+|_+$/g, '');

    const safeFilename = `${safeBase || 'file'}${safeExt || '.jpg'}`.slice(0, 100);

    const fileKey = `${folder}/${randomUUID()}-${safeFilename}`;
    const expiresIn = 900; // 15 minutos

    try {
      const command = new PutObjectCommand({
        Bucket: this.bucketName,
        Key: fileKey,
        ContentType: contentType,
      });

      const uploadUrl = await getSignedUrl(this.s3Client, command, { expiresIn });

      const publicUrl = this.publicUrlBase
        ? `${this.publicUrlBase.replace(/\/$/, '')}/${fileKey}`
        : `${this.endpoint.replace(/\/$/, '')}/${this.bucketName}/${fileKey}`;

      return {
        uploadUrl,
        fileKey,
        publicUrl,
        expiresIn,
        contentType,
      };
    } catch (error) {
      const err = error as Error;
      this.logger.error(`Error generando Presigned URL para ${fileKey}: ${err.message}`, err.stack);
      throw new InternalServerErrorException(
        'No se pudo generar la URL de subida segura. Intenta nuevamente.',
      );
    }
  }
}
