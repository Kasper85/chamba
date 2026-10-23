import { Test, TestingModule } from '@nestjs/testing';
import { ExecutionContext, INestApplication, UnauthorizedException, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/prisma/prisma.service.js';
import { JwtAuthGuard } from '../src/auth/guards/jwt-auth.guard.js';

describe('CHAMBA Location & PostGIS Geospatial Flow (e2e)', () => {
  let app: INestApplication;

  const mockAuthenticatedUser = {
    id: 'user-worker-777',
    email: 'tecnico.pro@chamba.pe',
    fullName: 'Jorge Quispe Baldera',
    status: 'ACTIVE',
  };

  const mockNearbyWorkers = [
    {
      workerProfileId: 'wp-101',
      userId: 'user-worker-777',
      fullName: 'Jorge Quispe Baldera',
      email: 'tecnico.pro@chamba.pe',
      phone: '+51 974 812 345',
      userDistrict: 'Santa Victoria, Chiclayo',
      workerDistrict: 'Santa Victoria, Chiclayo',
      specialty: 'Gasfitería',
      bio: 'Especialista en fugas y bombas de agua',
      rating: 4.9,
      completedJobs: 38,
      isAvailable: true,
      latitude: -6.7722,
      longitude: -79.8395,
      distanceMeters: 145.2,
      distanceKm: 0.15,
    },
    {
      workerProfileId: 'wp-102',
      userId: 'user-worker-888',
      fullName: 'Manuel Santisteban',
      email: 'manuel@chamba.pe',
      phone: '+51 974 555 123',
      userDistrict: 'Chiclayo Centro',
      workerDistrict: 'Chiclayo Centro',
      specialty: 'Electricidad',
      bio: 'Electricista matriculado',
      rating: 4.8,
      completedJobs: 24,
      isAvailable: true,
      latitude: -6.7785,
      longitude: -79.843,
      distanceMeters: 780.0,
      distanceKm: 0.78,
    },
  ];

  const mockPrisma = {
    $connect: vi.fn(),
    $disconnect: vi.fn(),
    workerProfile: {
      findUnique: vi.fn().mockImplementation(({ where }) => {
        if (where.userId === mockAuthenticatedUser.id) {
          return Promise.resolve({
            id: 'wp-101',
            userId: mockAuthenticatedUser.id,
            specialty: 'Gasfitería',
          });
        }
        return Promise.resolve(null);
      }),
    },
    $executeRaw: vi.fn().mockResolvedValue(1),
    $queryRaw: vi.fn().mockImplementation(() => {
      return Promise.resolve(mockNearbyWorkers);
    }),
  };

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(mockPrisma)
      .overrideGuard(JwtAuthGuard)
      .useValue({
        canActivate: (context: ExecutionContext) => {
          const req = context.switchToHttp().getRequest();
          const authHeader = req.headers['authorization'];
          if (authHeader && authHeader.startsWith('Bearer valid_worker_token')) {
            req.user = mockAuthenticatedUser;
            return true;
          }
          throw new UnauthorizedException('Token de autenticación requerido');
        },
      })
      .compile();

    app = moduleFixture.createNestApplication();
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

  describe('1. Búsqueda de técnicos cercanos (GET /api/v1/location/nearby)', () => {
    it('debe rechazar la petición con 400 si faltan lat o lng', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/location/nearby')
        .expect(400);

      await request(app.getHttpServer())
        .get('/api/v1/location/nearby?lat=-6.7725')
        .expect(400);
    });

    it('debe rechazar coordenadas fuera de rango (-90 a 90, -180 a 180) con 400', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/location/nearby?lat=95.0&lng=-79.8398')
        .expect(400);

      await request(app.getHttpServer())
        .get('/api/v1/location/nearby?lat=-6.7725&lng=-195.0')
        .expect(400);
    });

    it('debe devolver trabajadores cercanos con distancias y coordenadas con 200 OK', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/location/nearby?lat=-6.7725&lng=-79.8398&radiusKm=5')
        .expect(200);

      expect(response.body).toHaveProperty('searchCenter');
      expect(response.body.searchCenter.latitude).toBe(-6.7725);
      expect(response.body.searchCenter.longitude).toBe(-79.8398);
      expect(response.body.searchCenter.radiusKm).toBe(5);
      expect(response.body).toHaveProperty('count', 2);
      expect(response.body).toHaveProperty('workers');
      expect(response.body.workers[0].fullName).toBe('Jorge Quispe Baldera');
      expect(response.body.workers[0].distanceMeters).toBe(145.2);
    });

    it('debe admitir el filtro opcional por especialidad', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/location/nearby?lat=-6.7725&lng=-79.8398&radiusKm=3&specialty=Gasfitería')
        .expect(200);

      expect(response.body.searchCenter.specialty).toBe('Gasfitería');
    });
  });

  describe('2. Actualización de ubicación del técnico (PUT /api/v1/location/worker)', () => {
    it('debe rechazar solicitudes no autenticadas con 401', async () => {
      await request(app.getHttpServer())
        .put('/api/v1/location/worker')
        .send({ latitude: -6.7725, longitude: -79.8398 })
        .expect(401);
    });

    it('debe validar el payload rechazando coordenadas inválidas con 400', async () => {
      await request(app.getHttpServer())
        .put('/api/v1/location/worker')
        .set('Authorization', 'Bearer valid_worker_token')
        .send({ latitude: 'coordenada_invalida', longitude: -79.8398 })
        .expect(400);
    });

    it('debe actualizar la posición geoespacial en PostGIS con token válido', async () => {
      const response = await request(app.getHttpServer())
        .put('/api/v1/location/worker')
        .set('Authorization', 'Bearer valid_worker_token')
        .send({ latitude: -6.7725, longitude: -79.8398 })
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('message');
      expect(response.body.latitude).toBe(-6.7725);
      expect(response.body.longitude).toBe(-79.8398);
      expect(response.body.userId).toBe(mockAuthenticatedUser.id);
    });
  });
});
