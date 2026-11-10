import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { describe, expect, it, vi } from 'vitest';
import { RolesGuard } from './roles.guard.js';

describe('RolesGuard (Security Tests — ALCANCE.md §8 L12)', () => {
  const mockReflector = {
    getAllAndOverride: vi.fn(),
  };

  const mockConfigService = {
    get: vi.fn((key, defaultValue) => {
      if (key === 'SUPPORT_EMAILS') return 'soporte@chamba.pe,admin@chamba.pe';
      if (key === 'SUPPORT_USER_IDS') return 'usr-support-id-1';
      return defaultValue;
    }),
  };

  const guard = new RolesGuard(
    mockReflector as unknown as Reflector,
    mockConfigService as unknown as ConfigService,
  );

  function createMockContext(user: any): ExecutionContext {
    return {
      getHandler: () => ({}),
      getClass: () => ({}),
      switchToHttp: () => ({
        getRequest: () => ({ user }),
      }),
    } as unknown as ExecutionContext;
  }

  it('permite el acceso si la ruta no tiene roles requeridos', () => {
    mockReflector.getAllAndOverride.mockReturnValue(null);
    const ctx = createMockContext({ id: 'u1', role: 'CLIENT' });

    expect(guard.canActivate(ctx)).toBe(true);
  });

  it('rechaza con 403 Forbidden a un usuario normal con rol CLIENT o WORKER', () => {
    mockReflector.getAllAndOverride.mockReturnValue(['SUPPORT', 'ADMIN']);
    const ctx = createMockContext({ id: 'u1', email: 'cliente@gmail.com', role: 'CLIENT' });

    expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
  });

  it('permite el acceso a un usuario con rol SUPPORT en base de datos', () => {
    mockReflector.getAllAndOverride.mockReturnValue(['SUPPORT', 'ADMIN']);
    const ctx = createMockContext({ id: 'u2', email: 'soporte.personal@gmail.com', role: 'SUPPORT' });

    expect(guard.canActivate(ctx)).toBe(true);
  });

  it('permite el acceso a un usuario con rol ADMIN en base de datos', () => {
    mockReflector.getAllAndOverride.mockReturnValue(['SUPPORT', 'ADMIN']);
    const ctx = createMockContext({ id: 'u3', email: 'admin.personal@gmail.com', role: 'ADMIN' });

    expect(guard.canActivate(ctx)).toBe(true);
  });

  it('permite el acceso por variable de entorno SUPPORT_EMAILS (soporte@chamba.pe)', () => {
    mockReflector.getAllAndOverride.mockReturnValue(['SUPPORT', 'ADMIN']);
    const ctx = createMockContext({ id: 'u4', email: 'soporte@chamba.pe', role: 'CLIENT' });

    expect(guard.canActivate(ctx)).toBe(true);
  });

  it('permite el acceso por variable de entorno SUPPORT_USER_IDS', () => {
    mockReflector.getAllAndOverride.mockReturnValue(['SUPPORT', 'ADMIN']);
    const ctx = createMockContext({ id: 'usr-support-id-1', email: 'otro@gmail.com', role: 'CLIENT' });

    expect(guard.canActivate(ctx)).toBe(true);
  });
});
