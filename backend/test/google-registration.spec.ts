import { describe, it, expect, vi } from 'vitest';
import { AuthService } from '../src/auth/auth.service.js';

function setup(existing: unknown = null) {
  const user = { id: 'google-user', email: 'real@example.com', fullName: 'Nombre Real', status: 'ACTIVE', passwordHash: 'private-hash' };
  const prisma = { user: { findUnique: vi.fn().mockResolvedValue(existing), create: vi.fn().mockResolvedValue(user) } };
  const service = new AuthService(prisma as never, { sign: vi.fn().mockReturnValue('session-token') } as never);
  vi.spyOn(service as never, 'verifyGoogleToken').mockResolvedValue({ email: user.email, name: user.fullName, email_verified: true } as never);
  return { service, prisma };
}

describe('Google registration', () => {
  it('creates a session from a verified identity without a user password', async () => {
    const { service, prisma } = setup();
    const result = await service.prepareGoogleRegistration('identity-token');
    expect(result.user.email).toBe('real@example.com');
    expect(result.user).not.toHaveProperty('passwordHash');
    expect(result.accessToken).toBe('session-token');
    expect(prisma.user.create).toHaveBeenCalledOnce();
  });
  it('rejects an existing account without creating another', async () => {
    const { service, prisma } = setup({ id: 'existing' });
    await expect(service.prepareGoogleRegistration('identity-token')).rejects.toThrow('Ya existe');
    expect(prisma.user.create).not.toHaveBeenCalled();
  });
  it('does not create an account during login', async () => {
    const { service, prisma } = setup();
    await expect(service.loginWithGoogle('identity-token')).rejects.toThrow('no ha sido creada');
    expect(prisma.user.create).not.toHaveBeenCalled();
  });
});
