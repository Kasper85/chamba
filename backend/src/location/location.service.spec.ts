import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { LocationService, NearbyWorkerResult } from './location.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

describe('LocationService (Unit Tests)', () => {
  let service: LocationService;

  const mockPrismaService = {
    workerProfile: {
      findUnique: vi.fn(),
    },
    $executeRaw: vi.fn(),
    $queryRaw: vi.fn(),
  };

  beforeEach(async () => {
    vi.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LocationService,
        {
          provide: PrismaService,
          useValue: mockPrismaService,
        },
      ],
    }).compile();

    service = module.get<LocationService>(LocationService);
  });

  describe('updateWorkerLocation', () => {
    it('debe actualizar la ubicación del técnico con ST_SetSRID y ST_MakePoint en PostGIS', async () => {
      mockPrismaService.workerProfile.findUnique.mockResolvedValue({
        id: 'wp-100',
        userId: 'user-100',
      });
      mockPrismaService.$executeRaw.mockResolvedValue(1);

      const result = await service.updateWorkerLocation('user-100', -6.7725, -79.8398);

      expect(mockPrismaService.workerProfile.findUnique).toHaveBeenCalledWith({
        where: { userId: 'user-100' },
      });
      expect(mockPrismaService.$executeRaw).toHaveBeenCalled();
      expect(result).toHaveProperty('success', true);
      expect(result.workerProfileId).toBe('wp-100');
      expect(result.latitude).toBe(-6.7725);
      expect(result.longitude).toBe(-79.8398);
    });

    it('debe lanzar NotFoundException si el usuario no tiene perfil de trabajador', async () => {
      mockPrismaService.workerProfile.findUnique.mockResolvedValue(null);

      await expect(
        service.updateWorkerLocation('user-sin-perfil', -6.7725, -79.8398),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('findNearbyWorkers', () => {
    const mockWorkers: NearbyWorkerResult[] = [
      {
        workerProfileId: 'wp-1',
        userId: 'u-1',
        fullName: 'Jorge Quispe Baldera',
        email: 'jorge@chamba.pe',
        phone: '+51 974 812 345',
        userDistrict: 'Santa Victoria',
        workerDistrict: 'Santa Victoria',
        specialty: 'Gasfitería',
        bio: 'Gasfitero experto',
        rating: 4.9,
        completedJobs: 35,
        isAvailable: true,
        latitude: -6.7722,
        longitude: -79.8395,
        distanceMeters: 120.5,
        distanceKm: 0.12,
      },
      {
        workerProfileId: 'wp-2',
        userId: 'u-2',
        fullName: 'Manuel Santisteban',
        email: 'manuel@chamba.pe',
        phone: '+51 974 555 444',
        userDistrict: 'Chiclayo Centro',
        workerDistrict: 'Chiclayo Centro',
        specialty: 'Electricidad',
        bio: 'Electricista autorizado',
        rating: 4.8,
        completedJobs: 22,
        isAvailable: true,
        latitude: -6.779,
        longitude: -79.845,
        distanceMeters: 850.0,
        distanceKm: 0.85,
      },
    ];

    it('debe buscar técnicos en el radio especificado con ST_DWithin', async () => {
      mockPrismaService.$queryRaw.mockResolvedValue(mockWorkers);

      const workers = await service.findNearbyWorkers(-6.7725, -79.8398, 5);

      expect(mockPrismaService.$queryRaw).toHaveBeenCalled();
      expect(workers).toHaveLength(2);
      expect(workers[0].fullName).toBe('Jorge Quispe Baldera');
      expect(workers[0].distanceMeters).toBe(120.5);
      expect(workers[1].distanceKm).toBe(0.85);
    });

    it('debe filtrar por especialidad cuando se solicita', async () => {
      const filtered = [mockWorkers[0]];
      mockPrismaService.$queryRaw.mockResolvedValue(filtered);

      const workers = await service.findNearbyWorkers(-6.7725, -79.8398, 5, 'Gasfitería');

      expect(mockPrismaService.$queryRaw).toHaveBeenCalled();
      expect(workers).toHaveLength(1);
      expect(workers[0].specialty).toBe('Gasfitería');
    });
  });
});
