import { Test, TestingModule } from '@nestjs/testing';
import { WorkerProfileService } from './worker-profile.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

describe('WorkerProfileService (Loop L9 - Persistencia disponibilidad §8 L9)', () => {
  let service: WorkerProfileService;

  const mockPrismaService = {
    workerProfile: {
      findUnique: vi.fn(),
      upsert: vi.fn(),
    },
  };

  beforeEach(async () => {
    vi.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WorkerProfileService,
        {
          provide: PrismaService,
          useValue: mockPrismaService,
        },
      ],
    }).compile();

    service = module.get<WorkerProfileService>(WorkerProfileService);
  });

  describe('updateAvailability', () => {
    it('debe persistir el cambio de disponibilidad del chambeador en base de datos', async () => {
      mockPrismaService.workerProfile.upsert.mockResolvedValue({
        id: 'wp-1',
        userId: 'worker-user-1',
        isAvailable: false,
      });

      const result = await service.updateAvailability('worker-user-1', false);

      expect(mockPrismaService.workerProfile.upsert).toHaveBeenCalledWith({
        where: { userId: 'worker-user-1' },
        update: { isAvailable: false },
        create: {
          userId: 'worker-user-1',
          isAvailable: false,
          bio: 'Técnico especialista',
          specialty: 'Servicios Generales',
        },
        select: {
          id: true,
          userId: true,
          isAvailable: true,
        },
      });
      expect(result.isAvailable).toBe(false);
    });
  });
});

