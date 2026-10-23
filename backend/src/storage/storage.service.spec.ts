import { describe, it, expect, beforeEach } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { StorageService } from './storage.service.js';

describe('StorageService', () => {
  let service: StorageService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        StorageService,
        {
          provide: ConfigService,
          useValue: {
            get: (key: string, defaultValue?: any) => {
              const mockConfig: Record<string, any> = {
                R2_ACCOUNT_ID: 'test-account-123',
                R2_ACCESS_KEY_ID: 'test-key-id',
                R2_SECRET_ACCESS_KEY: 'test-secret-key',
                R2_BUCKET_NAME: 'chamba-test-bucket',
                R2_PUBLIC_URL: 'https://pub-chamba.test.dev',
              };
              return mockConfig[key] ?? defaultValue;
            },
          },
        },
      ],
    }).compile();

    service = module.get<StorageService>(StorageService);
  });

  it('debe estar definido', () => {
    expect(service).toBeDefined();
  });

  it('debe generar una Presigned URL válida y segura para Cloudflare R2', async () => {
    const res = await service.createPresignedUploadUrl({
      filename: 'foto_fuga.jpg',
      contentType: 'image/jpeg',
      folder: 'diagnostics',
    });

    expect(res).toBeDefined();
    expect(res.uploadUrl).toContain('https://');
    expect(res.uploadUrl).toContain('X-Amz-Signature=');
    expect(res.uploadUrl).toContain('X-Amz-Expires=900');
    expect(res.fileKey).toMatch(/^diagnostics\/[0-9a-f-]+-foto_fuga\.jpg$/);
    expect(res.publicUrl).toBe(`https://pub-chamba.test.dev/${res.fileKey}`);
    expect(res.contentType).toBe('image/jpeg');
    expect(res.expiresIn).toBe(900);
  });

  it('debe sanitizar nombres de archivo sospechosos o con caracteres especiales', async () => {
    const res = await service.createPresignedUploadUrl({
      filename: '../../malicious script & <tag>.png',
      contentType: 'image/png',
      folder: 'evidence',
    });

    expect(res.fileKey).toMatch(/^evidence\/[0-9a-f-]+-malicious_script_tag\.png$/);
    expect(res.fileKey).not.toContain('../');
    expect(res.fileKey).not.toContain('<tag>');
  });
});
