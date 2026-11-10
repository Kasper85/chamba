import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { ROLES_KEY } from '../decorators/roles.decorator.js';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private configService: ConfigService,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user) {
      throw new ForbiddenException('Acceso denegado: Usuario no autenticado');
    }

    // 1. Verificación por campo de rol en el usuario (BD / token)
    const userRole = (user.role ?? '').toUpperCase();
    const hasRole = requiredRoles.map((r) => r.toUpperCase()).includes(userRole);
    if (hasRole) {
      return true;
    }

    // 2. Verificación de respaldo por correos o IDs de soporte en variables de entorno
    const supportEmailsRaw = this.configService.get<string>(
      'SUPPORT_EMAILS',
      'soporte@chamba.pe,admin@chamba.pe',
    );
    const supportEmails = supportEmailsRaw
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .filter((e) => e.length > 0);

    const supportIdsRaw = this.configService.get<string>('SUPPORT_USER_IDS', '');
    const supportIds = supportIdsRaw
      .split(',')
      .map((id) => id.trim())
      .filter((id) => id.length > 0);

    const userEmail = (user.email ?? '').toLowerCase();
    const isSupportByEnv =
      (userEmail && supportEmails.includes(userEmail)) ||
      (user.id && supportIds.includes(user.id));

    if (
      isSupportByEnv &&
      (requiredRoles.includes('SUPPORT') || requiredRoles.includes('ADMIN'))
    ) {
      return true;
    }

    throw new ForbiddenException(
      `Acceso denegado: Se requiere rol de [${requiredRoles.join(', ')}] para realizar esta acción`,
    );
  }
}
