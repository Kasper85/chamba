import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/prisma/prisma.service.js';

describe('Cloud Integrations: Cloudflare R2 Presigned URLs & Gemini AI (e2e)', () => {
  let app: INestApplication;

  const mockPrisma = {
    $connect: () => Promise.resolve(),
    $disconnect: () => Promise.resolve(),
  };

  beforeAll(async () => {
    const moduleRef: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(mockPrisma)
      .compile();

    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
      }),
    );

    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('1. Almacenamiento Seguro (Cloudflare R2 / S3 Presigned URLs)', () => {
    it('GET /api/v1/storage/upload-url — debe generar una URL prefirmada para subida directa', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/storage/upload-url')
        .query({
          filename: 'fuga_cocina.jpg',
          contentType: 'image/jpeg',
          folder: 'diagnostics',
        })
        .expect(200);

      expect(res.body).toBeDefined();
      expect(res.body.uploadUrl).toBeDefined();
      expect(res.body.uploadUrl).toContain('https://');
      expect(res.body.uploadUrl).toContain('X-Amz-Signature=');
      expect(res.body.fileKey).toMatch(/^diagnostics\/[0-9a-f-]+-fuga_cocina\.jpg$/);
      expect(res.body.expiresIn).toBe(900);
      expect(res.body.contentType).toBe('image/jpeg');
      expect(res.body.publicUrl).toBeDefined();
    });

    it('GET /api/v1/storage/upload-url — debe soportar notas de voz y audios de averías', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/storage/upload-url')
        .query({
          filename: 'nota_audio.m4a',
          contentType: 'audio/m4a',
          folder: 'audio',
        })
        .expect(200);

      expect(res.body.fileKey).toMatch(/^audio\/[0-9a-f-]+-nota_audio\.m4a$/);
      expect(res.body.contentType).toBe('audio/m4a');
    });

    it('GET /api/v1/storage/upload-url — debe sanitizar nombres con path traversal', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/storage/upload-url')
        .query({
          filename: '../../etc/passwd.jpg',
          folder: 'evidence',
        })
        .expect(200);

      expect(res.body.fileKey).not.toContain('../');
      expect(res.body.fileKey).toContain('passwd.jpg');
    });
  });

  describe('2. Diagnóstico Visual con IA (Gemini API / Motor de Respaldo)', () => {
    it('POST /api/v1/ai/diagnose — debe diagnosticar avería de gasfitería con JSON estructurado', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/ai/diagnose')
        .send({
          imageUrl: 'https://pub-chamba.r2.dev/diagnostics/tuberia_goteando.jpg',
          prompt: 'Tubería goteando bajo lavadero de cocina. Hay fuga de agua constante.',
        })
        .expect(200);

      expect(res.body).toBeDefined();
      expect(res.body.category).toBe('Gasfitería');
      expect(res.body.technicalDescription).toBeDefined();
      expect(typeof res.body.technicalDescription).toBe('string');

      // Structured Output: estimatedPriceRange
      expect(res.body.estimatedPriceRange).toBeDefined();
      expect(res.body.estimatedPriceRange.min).toBeGreaterThan(0);
      expect(res.body.estimatedPriceRange.max).toBeGreaterThan(res.body.estimatedPriceRange.min);
      expect(res.body.estimatedPriceRange.currency).toBe('PEN');
      expect(res.body.estimatedPriceRange.formatted).toMatch(/^S\/\.\s*\d+/);

      // Structured Output: materialsNeeded
      expect(Array.isArray(res.body.materialsNeeded)).toBe(true);
      expect(res.body.materialsNeeded.length).toBeGreaterThan(0);
      expect(res.body.materialsNeeded).toContain('Cinta teflón 3/4"');
    });

    it('POST /api/v1/ai/diagnose — debe diagnosticar avería eléctrica (enchufe chispeando)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/ai/diagnose')
        .send({
          imageUrl: 'https://pub-chamba.r2.dev/diagnostics/enchufe_quemado.jpg',
          prompt: 'Enchufe botando chispas y olor a quemado en pared de sala.',
        })
        .expect(200);

      expect(res.body.category).toBe('Electricidad');
      expect(res.body.estimatedPriceRange.formatted).toBe('S/. 40 - S/. 55');
      expect(res.body.materialsNeeded).toContain('Tomacorriente doble con tierra Ticino');
    });

    it('POST /api/v1/ai/diagnose — debe diagnosticar avería de carpintería (puerta trabada)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/ai/diagnose')
        .send({
          imageUrl: 'https://pub-chamba.r2.dev/diagnostics/puerta_madera.jpg',
          prompt: 'Puerta de madera trabada no abre y roza el marco.',
        })
        .expect(200);

      expect(res.body.category).toBe('Carpintería');
      expect(res.body.materialsNeeded).toContain('Bisagras de acero 3x3"');
    });

    it('POST /api/v1/ai/diagnose — debe rechazar solicitudes sin imageUrl con 400 Bad Request', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/ai/diagnose')
        .send({
          prompt: 'Avería sin evidencia fotográfica',
        })
        .expect(400);

      expect(res.body.message).toBeDefined();
    });
  });
});
