import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { WsException } from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Socket } from 'socket.io';

@Injectable()
export class WsJwtGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const client: Socket = context.switchToWs().getClient<Socket>();

    // Si ya fue autenticado en handleConnection, se permite de inmediato
    if (client.data?.user) {
      return true;
    }

    const authHeader = client.handshake.headers.authorization;
    const authToken = client.handshake.auth?.token;

    const token = authToken || (authHeader?.startsWith('Bearer ') ? authHeader.split(' ')[1] : authHeader);

    if (!token) {
      throw new WsException('Token de autenticación WebSocket no proporcionado');
    }

    try {
      const secret = this.configService.get<string>(
        'JWT_SECRET',
        'chamba_desarrollo_secreto_super_seguro_jwt_2026',
      );
      const payload = this.jwtService.verify(token, { secret });
      client.data.user = payload;
      return true;
    } catch {
      throw new WsException('Token de autenticación WebSocket inválido o expirado');
    }
  }
}
