import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  InternalServerErrorException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { OAuth2Client } from 'google-auth-library';
import { randomBytes } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';

@Injectable()
export class AuthService {
  private readonly googleClientId = process.env.GOOGLE_WEB_CLIENT_ID;
  private readonly googleClient = this.googleClientId
    ? new OAuth2Client(this.googleClientId)
    : null;

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
  ) {}

  async register(registerDto: RegisterDto) {
    const existing = await this.prisma.user.findUnique({
      where: { email: registerDto.email.toLowerCase().trim() },
    });

    if (existing) {
      throw new ConflictException('El correo electrónico ya se encuentra registrado');
    }

    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(registerDto.password, saltRounds);

    try {
      const user = await this.prisma.user.create({
        data: {
          fullName: registerDto.fullName.trim(),
          email: registerDto.email.toLowerCase().trim(),
          passwordHash,
          phone: registerDto.phone?.trim(),
          district: registerDto.district?.trim(),
          address: registerDto.address?.trim(),
        },
        include: { workerProfile: true },
      });

      const { passwordHash: _, ...safeUser } = user;
      const accessToken = this.generateToken(safeUser.id, safeUser.email);

      return {
        message: 'Usuario registrado exitosamente',
        user: safeUser,
        accessToken,
      };
    } catch {
      throw new InternalServerErrorException('Error al crear la cuenta de usuario');
    }
  }

  async login(loginDto: LoginDto) {
    const email = loginDto.email.toLowerCase().trim();
    const user = await this.prisma.user.findUnique({
      where: { email },
      include: { workerProfile: true },
    });

    if (!user) {
      throw new UnauthorizedException('No existe una cuenta con este correo. Regístrate primero.');
    }

    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedException('Esta cuenta está inactiva o suspendida');
    }

    const isPasswordValid = await bcrypt.compare(loginDto.password, user.passwordHash);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const { passwordHash: _, ...safeUser } = user;
    const accessToken = this.generateToken(safeUser.id, safeUser.email);

    return {
      message: 'Inicio de sesión exitoso',
      user: safeUser,
      accessToken,
    };
  }


  async loginWithGoogle(idToken: string) {
    const payload = await this.verifyGoogleToken(idToken);
    const email = payload.email!.toLowerCase().trim();
    const user = await this.prisma.user.findUnique({ where: { email }, include: { workerProfile: true } });
    if (!user) throw new UnauthorizedException('Esta cuenta de Google no ha sido creada. Regístrate primero.');
    if (user.status !== 'ACTIVE') throw new UnauthorizedException('Esta cuenta está inactiva o suspendida');
    const { passwordHash: _, ...safeUser } = user;
    return { message: 'Inicio de sesión con Google exitoso', user: safeUser, accessToken: this.generateToken(safeUser.id, safeUser.email) };
  }

  async prepareGoogleRegistration(idToken: string) {
    const payload = await this.verifyGoogleToken(idToken);
    const email = payload.email!.toLowerCase().trim();
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new ConflictException('Ya existe una cuenta con este correo. Inicia sesión.');
    const passwordHash = await bcrypt.hash(randomBytes(32).toString('hex'), 10);
    try {
      const user = await this.prisma.user.create({
        data: { email, fullName: payload.name?.trim() || '', passwordHash, status: 'ACTIVE' },
        include: { workerProfile: true },
      });
      const { passwordHash: _, ...safeUser } = user;
      return { message: 'Cuenta creada con Google', user: safeUser, accessToken: this.generateToken(user.id, user.email) };
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') throw new ConflictException('Ya existe una cuenta con este correo. Inicia sesión.');
      throw error;
    }
  }

  private async verifyGoogleToken(idToken: string) {
    if (!this.googleClient || !this.googleClientId) throw new InternalServerErrorException('El inicio de sesión con Google no está configurado');
    try {
      const ticket = await this.googleClient.verifyIdToken({ idToken, audience: this.googleClientId });
      const payload = ticket.getPayload();
      if (!payload?.email || payload.email_verified !== true) throw new UnauthorizedException('La cuenta de Google no tiene un correo verificado');
      return payload;
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;
      throw new UnauthorizedException('El token de Google no es válido');
    }
  }

  private generateToken(userId: string, email: string): string {
    const payload = { sub: userId, email };
    return this.jwtService.sign(payload);
  }
}
