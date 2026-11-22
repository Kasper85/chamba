import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { PortfolioDto } from './dto/portfolio.dto.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { UpsertWorkerProfileDto } from './dto/upsert-worker-profile.dto.js';

@Injectable()
export class WorkerProfileService {
  async addPortfolio(userId: string, dto: PortfolioDto) {
    for (const image of [dto.beforeImageUrl, dto.afterImageUrl]) {
      const bytes = Buffer.from(image.split(',')[1] ?? '', 'base64');
      if (bytes.length > 500000 || bytes[0] !== 255 || bytes[1] !== 216) throw new BadRequestException('Usa fotos JPEG de hasta 500 KB');
    }
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM worker_profiles WHERE user_id = ${userId} FOR UPDATE`;
      const profile = await tx.workerProfile.findUnique({ where: { userId } });
      if (!profile) throw new NotFoundException('Completa primero tu perfil de especialista');
      const projects = Array.isArray(profile.portfolio) ? profile.portfolio : [];
      if (projects.length >= 5) throw new BadRequestException('Tu portafolio permite hasta 5 obras');
      return tx.workerProfile.update({ where: { userId }, data: { portfolio: [...projects, { ...dto, id: randomUUID(), timeSpent: '', cost: 0 }] } });
    });
  }
  constructor(private prisma: PrismaService) {}

  async findMyProfile(userId: string) {
    const profile = await this.prisma.workerProfile.findUnique({
      where: { userId },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            district: true,
            address: true,
          },
        },
      },
    });

    if (!profile) {
      throw new NotFoundException('El usuario aún no tiene un perfil de trabajador configurado');
    }

    return profile;
  }

  async upsertMyProfile(userId: string, dto: UpsertWorkerProfileDto) {
    return this.prisma.workerProfile.upsert({
      where: { userId },
      update: {
        dni: dto.dni === undefined ? undefined : (dto.dni.trim() || null),
        baseRate: dto.baseRate,
        serviceRadiusKm: dto.serviceRadiusKm,
        experienceYears: dto.experienceYears,
        skills: dto.skills,
        bio: dto.bio.trim() || null,
        district: dto.district?.trim(),
        specialty: dto.specialty.trim() || null,
        ...(dto.isAvailable !== undefined ? { isAvailable: dto.isAvailable } : {}),
      },
      create: {
        dni: dto.dni?.trim() || null,
        baseRate: dto.baseRate,
        serviceRadiusKm: dto.serviceRadiusKm,
        experienceYears: dto.experienceYears,
        skills: dto.skills,
        userId,
        bio: dto.bio.trim() || null,
        district: dto.district?.trim(),
        specialty: dto.specialty.trim() || null,
        isAvailable: dto.isAvailable ?? true,
      },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            district: true,
            address: true,
          },
        },
      },
    });
  }

  async updateAvailability(userId: string, isAvailable: boolean) {
    return this.prisma.workerProfile.upsert({
      where: { userId },
      update: { isAvailable },
      create: {
        userId,
        isAvailable,
      },
      select: {
        id: true,
        userId: true,
        isAvailable: true,
      },
    });
  }
}
