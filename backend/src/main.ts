import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module.js';
import { RedisIoAdapter } from './events/adapters/redis-io.adapter.js';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Prefijo global de API versionada
  app.setGlobalPrefix('api/v1');

  // Habilitar CORS para permitir peticiones desde Flutter móvil, web y Postman
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  // Validaciones globales de DTO con transformación automática
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // Configuración del adaptador Socket.IO con Redis para escalamiento horizontal
  const redisIoAdapter = new RedisIoAdapter(app);
  await redisIoAdapter.connectToRedis();
  app.useWebSocketAdapter(redisIoAdapter);

  // Documentación interactiva Swagger / OpenAPI
  const config = new DocumentBuilder()
    .setTitle('CHAMBA API')
    .setDescription('API REST oficial para la plataforma CHAMBA Perú — Fase 1: Autenticación, Usuarios y Perfil de Trabajador')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(`🚀 CHAMBA Backend ejecutándose en: http://localhost:${port}/api/v1`);
  console.log(`📚 Documentación Swagger disponible en: http://localhost:${port}/api/docs`);
}
void bootstrap();
