import { describe, it, expect, vi } from 'vitest';
import { WorkerProfileService } from '../src/worker-profile/worker-profile.service.js';
import { hidePrivateIdentity } from '../src/worker-profile/private-identity.interceptor.js';

describe('Worker profile persistence and privacy', () => {
  it('keeps an incomplete professional profile empty instead of inventing data', async () => {
    const upsert = vi.fn().mockResolvedValue({ id: 'worker' });
    const service = new WorkerProfileService({ workerProfile: { upsert } } as never);
    await service.upsertMyProfile('user', { bio: '', specialty: '' });
    expect(upsert.mock.calls[0][0].create).toMatchObject({ userId: 'user', bio: null, specialty: null });
    expect(upsert.mock.calls[0][0].create.experienceYears).toBeUndefined();
    expect(upsert.mock.calls[0][0].create.dni).toBeNull();
  });
  it('persists all editable professional fields', async () => {
    const upsert = vi.fn().mockResolvedValue({ id: 'worker' });
    const service = new WorkerProfileService({ workerProfile: { upsert } } as never);
    await service.upsertMyProfile('user', { bio: 'Mi experiencia', specialty: 'Electricidad', dni: '12345678', baseRate: 70, serviceRadiusKm: 10, experienceYears: 0, skills: ['Electricidad', 'Pintura'] });
    const data = upsert.mock.calls[0][0];
    for (const branch of [data.create, data.update]) {
      expect(branch).toMatchObject({ dni: '12345678', baseRate: 70, serviceRadiusKm: 10, experienceYears: 0, skills: ['Electricidad', 'Pintura'] });
    }
  });
  it('removes private DNI from nested public data without changing dates', () => {
    const date = new Date();
    const result = hidePrivateIdentity({ worker: { dni: '12345678', name: 'Persona' }, bids: [{ worker: { dni: '87654321' } }], date });
    expect(result).toEqual({ worker: { name: 'Persona' }, bids: [{ worker: {} }], date });
  });
  it('rejects invalid portfolio images before persistence', async () => {
    const service = new WorkerProfileService({} as never);
    await expect(service.addPortfolio('user', { title: 'Trabajo', category: '', beforeDescription: '', afterDescription: '', beforeImageUrl: 'data:image/jpeg;base64,AA==', afterImageUrl: 'data:image/jpeg;base64,AA==' })).rejects.toThrow('JPEG');
  });
});
