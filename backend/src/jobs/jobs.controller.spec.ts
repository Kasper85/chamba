import { Test, TestingModule } from '@nestjs/testing';
import { JobsController } from './jobs.controller.js';
import { JobsService } from './jobs.service.js';
import { JobStatus } from '../common/job-state-machine.js';

describe('JobsController', () => {
  let controller: JobsController;
  let service: JobsService;

  const mockJobsService = {
    createJob: vi.fn(),
    findAll: vi.fn(),
    findOne: vi.fn(),
    createBid: vi.fn(),
    counterBid: vi.fn(),
    acceptBid: vi.fn(),
    updatePhase: vi.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [JobsController],
      providers: [
        {
          provide: JobsService,
          useValue: mockJobsService,
        },
      ],
    }).compile();

    controller = module.get<JobsController>(JobsController);
    service = module.get<JobsService>(JobsService);
  });

  it('debe crear una chamba delegando al servicio', async () => {
    const dto = {
      title: 'Reparar chapa',
      description: 'Chapa trabada en puerta principal',
      category: 'cerrajeria',
      budget: 50.0,
      district: 'La Victoria',
    };
    mockJobsService.createJob.mockResolvedValue({ id: 'job-123', ...dto });

    const result = await controller.createJob({ id: 'user-1' }, dto);
    expect(service.createJob).toHaveBeenCalledWith('user-1', dto);
    expect(result.id).toBe('job-123');
  });

  it('debe listar chambas delegando al servicio', async () => {
    mockJobsService.findAll.mockResolvedValue([]);
    const result = await controller.findAll({ id: 'user-1' }, { role: 'client' });
    expect(service.findAll).toHaveBeenCalledWith('user-1', { role: 'client' });
    expect(result).toEqual([]);
  });

  it('debe permitir aceptar una oferta delegando al servicio', async () => {
    mockJobsService.acceptBid.mockResolvedValue({ id: 'job-1', status: JobStatus.ACEPTADA });
    const result = await controller.acceptBid({ id: 'user-1' }, 'job-1', 'bid-1');
    expect(service.acceptBid).toHaveBeenCalledWith('user-1', 'job-1', 'bid-1');
    expect(result.status).toBe(JobStatus.ACEPTADA);
  });

  it('debe actualizar la fase de una chamba delegando al servicio', async () => {
    const dto = {
      phase: JobStatus.EN_CAMINO,
    };
    mockJobsService.updatePhase.mockResolvedValue({ id: 'job-1', status: JobStatus.EN_CAMINO });
    const result = await controller.updatePhase({ id: 'worker-1' }, 'job-1', dto);
    expect(service.updatePhase).toHaveBeenCalledWith('worker-1', 'job-1', dto);
    expect(result.status).toBe(JobStatus.EN_CAMINO);
  });
});

