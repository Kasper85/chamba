import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { UpsertWorkerProfileDto } from './dto/upsert-worker-profile.dto.js';

@Injectable()
export class WorkerProfileService {
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
        bio: dto.bio.trim(),
        district: dto.district?.trim(),
        specialty: dto.specialty.trim(),
        ...(dto.isAvailable !== undefined ? { isAvailable: dto.isAvailable } : {}),
      },
      create: {
        userId,
        bio: dto.bio.trim(),
        district: dto.district?.trim(),
        specialty: dto.specialty.trim(),
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
        bio: 'Técnico especialista',
        specialty: 'Servicios Generales',
      },
      select: {
        id: true,
        userId: true,
        isAvailable: true,
      },
    });
  }
}
