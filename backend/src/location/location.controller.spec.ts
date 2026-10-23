import { Test, TestingModule } from '@nestjs/testing';
import { LocationController } from './location.controller.js';
import { LocationService } from './location.service.js';

describe('LocationController (Unit Tests)', () => {
  let controller: LocationController;

  const mockLocationService = {
    updateWorkerLocation: vi.fn(),
    findNearbyWorkers: vi.fn(),
    getWorkerLocation: vi.fn(),
  };

  beforeEach(async () => {
    vi.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [LocationController],
      providers: [
        {
          provide: LocationService,
          useValue: mockLocationService,
        },
      ],
    }).compile();

    controller = module.get<LocationController>(LocationController);
  });

  describe('PUT /location/worker', () => {
    it('debe actualizar la ubicación del técnico autenticado', async () => {
      mockLocationService.updateWorkerLocation.mockResolvedValue({
        success: true,
        latitude: -6.7725,
        longitude: -79.8398,
      });

      const result = await controller.updateWorkerLocation(
        { id: 'worker-user-1' },
        { latitude: -6.7725, longitude: -79.8398 },
      );

      expect(mockLocationService.updateWorkerLocation).toHaveBeenCalledWith(
        'worker-user-1',
        -6.7725,
        -79.8398,
      );
      expect(result).toEqual({
        success: true,
        latitude: -6.7725,
        longitude: -79.8398,
      });
    });
  });

  describe('GET /location/nearby', () => {
    it('debe buscar técnicos cercanos con radio por defecto', async () => {
      const mockNearby = [
        {
          workerProfileId: 'wp-1',
          fullName: 'Jorge Quispe',
          distanceKm: 0.8,
        },
      ];
      mockLocationService.findNearbyWorkers.mockResolvedValue(mockNearby);

      const result = await controller.findNearbyWorkers({
        lat: -6.7725,
        lng: -79.8398,
      });

      expect(mockLocationService.findNearbyWorkers).toHaveBeenCalledWith(
        -6.7725,
        -79.8398,
        5,
        undefined,
      );
      expect(result.count).toBe(1);
      expect(result.workers).toEqual(mockNearby);
      expect(result.searchCenter.radiusKm).toBe(5);
    });

    it('debe respetar el radio personalizado y la especialidad', async () => {
      mockLocationService.findNearbyWorkers.mockResolvedValue([]);

      const result = await controller.findNearbyWorkers({
        lat: -6.7725,
        lng: -79.8398,
        radiusKm: 12,
        specialty: 'Electricidad',
      });

      expect(mockLocationService.findNearbyWorkers).toHaveBeenCalledWith(
        -6.7725,
        -79.8398,
        12,
        'Electricidad',
      );
      expect(result.searchCenter.radiusKm).toBe(12);
      expect(result.searchCenter.specialty).toBe('Electricidad');
    });
  });
});
