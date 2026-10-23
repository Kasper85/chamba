import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

export interface NearbyWorkerResult {
  workerProfileId: string;
  userId: string;
  fullName: string;
  email: string;
  phone: string | null;
  userDistrict: string | null;
  workerDistrict: string | null;
  specialty: string | null;
  bio: string | null;
  rating: number;
  completedJobs: number;
  isAvailable: boolean;
  latitude: number;
  longitude: number;
  distanceMeters: number;
  distanceKm: number;
}

@Injectable()
export class LocationService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Actualiza la ubicación geoespacial de un trabajador en PostgreSQL usando PostGIS.
   * Utiliza ST_SetSRID y ST_MakePoint(lng, lat) con el elipsoide WGS 84 (SRID 4326).
   */
  async updateWorkerLocation(userId: string, latitude: number, longitude: number) {
    // 1. Validar que exista el perfil de trabajador para este usuario
    const workerProfile = await this.prisma.workerProfile.findUnique({
      where: { userId },
    });

    if (!workerProfile) {
      throw new NotFoundException(
        'Perfil de trabajador no encontrado para este usuario. Primero configura tu perfil de trabajador.',
      );
    }

    // 2. Ejecutar actualización SQL cruda con PostGIS
    // Importante en PostGIS: ST_MakePoint recibe primero Longitud (X) y luego Latitud (Y)
    await this.prisma.$executeRaw`
      UPDATE "worker_profiles"
      SET "location" = ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326),
          "updated_at" = NOW()
      WHERE "user_id" = ${userId}
    `;

    return {
      success: true,
      message: 'Ubicación geoespacial del trabajador actualizada con éxito en PostGIS',
      workerProfileId: workerProfile.id,
      userId,
      latitude,
      longitude,
      updatedAt: new Date().toISOString(),
    };
  }

  /**
   * Busca trabajadores cercanos dentro de un radio en kilómetros usando consultas espaciales nativas.
   * Optimizado con GiST Index en ST_DWithin(location::geography, point::geography, radiusMeters).
   * Devuelve distancias precisas en metros y kilómetros ordenadas de menor a mayor.
   */
  async findNearbyWorkers(
    lat: number,
    lng: number,
    radiusKm: number = 5,
    specialty?: string,
  ): Promise<NearbyWorkerResult[]> {
    const radiusMeters = radiusKm * 1000;

    if (specialty && specialty.trim()) {
      const specialtyTrimmed = specialty.trim();
      return this.prisma.$queryRaw<NearbyWorkerResult[]>`
        SELECT
          wp.id AS "workerProfileId",
          wp.user_id AS "userId",
          u.full_name AS "fullName",
          u.email AS "email",
          u.phone AS "phone",
          u.district AS "userDistrict",
          wp.district AS "workerDistrict",
          wp.specialty AS "specialty",
          wp.bio AS "bio",
          wp.rating::float AS "rating",
          wp.completed_jobs AS "completedJobs",
          wp.is_available AS "isAvailable",
          ROUND(ST_Y(wp.location::geometry)::numeric, 6)::float AS "latitude",
          ROUND(ST_X(wp.location::geometry)::numeric, 6)::float AS "longitude",
          ROUND(ST_Distance(wp.location::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography)::numeric, 1)::float AS "distanceMeters",
          ROUND((ST_Distance(wp.location::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography) / 1000.0)::numeric, 2)::float AS "distanceKm"
        FROM "worker_profiles" wp
        INNER JOIN "users" u ON u.id = wp.user_id
        WHERE wp.location IS NOT NULL
          AND u.status = 'ACTIVE'
          AND LOWER(wp.specialty) = LOWER(${specialtyTrimmed})
          AND ST_DWithin(
            wp.location::geography,
            ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography,
            ${radiusMeters}
          )
        ORDER BY "distanceMeters" ASC
      `;
    }

    return this.prisma.$queryRaw<NearbyWorkerResult[]>`
      SELECT
        wp.id AS "workerProfileId",
        wp.user_id AS "userId",
        u.full_name AS "fullName",
        u.email AS "email",
        u.phone AS "phone",
        u.district AS "userDistrict",
        wp.district AS "workerDistrict",
        wp.specialty AS "specialty",
        wp.bio AS "bio",
        wp.rating::float AS "rating",
        wp.completed_jobs AS "completedJobs",
        wp.is_available AS "isAvailable",
        ROUND(ST_Y(wp.location::geometry)::numeric, 6)::float AS "latitude",
        ROUND(ST_X(wp.location::geometry)::numeric, 6)::float AS "longitude",
        ROUND(ST_Distance(wp.location::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography)::numeric, 1)::float AS "distanceMeters",
        ROUND((ST_Distance(wp.location::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography) / 1000.0)::numeric, 2)::float AS "distanceKm"
      FROM "worker_profiles" wp
      INNER JOIN "users" u ON u.id = wp.user_id
      WHERE wp.location IS NOT NULL
        AND u.status = 'ACTIVE'
        AND ST_DWithin(
          wp.location::geography,
          ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography,
          ${radiusMeters}
        )
      ORDER BY "distanceMeters" ASC
    `;
  }

  /**
   * Obtiene la posición actual guardada de un trabajador.
   */
  async getWorkerLocation(userId: string) {
    const result = await this.prisma.$queryRaw<Array<{
      workerProfileId: string;
      userId: string;
      latitude: number | null;
      longitude: number | null;
    }>>`
      SELECT
        id AS "workerProfileId",
        user_id AS "userId",
        CASE WHEN location IS NOT NULL THEN ROUND(ST_Y(location::geometry)::numeric, 6)::float ELSE NULL END AS "latitude",
        CASE WHEN location IS NOT NULL THEN ROUND(ST_X(location::geometry)::numeric, 6)::float ELSE NULL END AS "longitude"
      FROM "worker_profiles"
      WHERE "user_id" = ${userId}
    `;

    if (!result || result.length === 0) {
      throw new NotFoundException('Perfil de trabajador no encontrado para este usuario');
    }

    return result[0];
  }
}
