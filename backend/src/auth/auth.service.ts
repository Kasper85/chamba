import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  InternalServerErrorException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';

@Injectable()
export class AuthService {
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
      throw new UnauthorizedException('Credenciales inválidas');
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

  private generateToken(userId: string, email: string): string {
    const payload = { sub: userId, email };
    return this.jwtService.sign(payload);
  }
}
