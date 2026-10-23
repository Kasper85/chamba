import { Body, Controller, Get, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { LocationService } from './location.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { UpdateWorkerLocationDto } from './dto/update-worker-location.dto.js';
import { FindNearbyWorkersDto } from './dto/find-nearby-workers.dto.js';

@ApiTags('Location & Geospatial')
@Controller('location')
export class LocationController {
  constructor(private readonly locationService: LocationService) {}

  @Put('worker')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Actualizar la ubicación GPS actual del técnico autenticado',
    description: 'Actualiza la columna PostGIS "location" (Point, 4326) con coordenadas GPS WGS 84.',
  })
  @ApiResponse({ status: 200, description: 'Ubicación actualizada con éxito en PostGIS' })
  @ApiResponse({ status: 401, description: 'No autorizado / Token ausente o expirado' })
  @ApiResponse({ status: 404, description: 'Perfil de trabajador no encontrado para este usuario' })
  async updateWorkerLocation(
    @CurrentUser() user: { id: string },
    @Body() dto: UpdateWorkerLocationDto,
  ) {
    return this.locationService.updateWorkerLocation(user.id, dto.latitude, dto.longitude);
  }

  @Get('nearby')
  @ApiOperation({
    summary: 'Buscar técnicos cercanos en milisegundos mediante PostGIS',
    description: 'Realiza una consulta espacial indexada con ST_DWithin y ST_MakePoint en base a latitud, longitud y radio en km.',
  })
  @ApiResponse({ status: 200, description: 'Listado de trabajadores cercanos con distancia calculada' })
  @ApiResponse({ status: 400, description: 'Parámetros de coordenadas o radio inválidos' })
  async findNearbyWorkers(@Query() query: FindNearbyWorkersDto) {
    const radiusKm = query.radiusKm ?? 5;
    const workers = await this.locationService.findNearbyWorkers(
      query.lat,
      query.lng,
      radiusKm,
      query.specialty,
    );

    return {
      searchCenter: {
        latitude: query.lat,
        longitude: query.lng,
        radiusKm,
        specialty: query.specialty ?? null,
      },
      count: workers.length,
      workers,
    };
  }

  @Get('worker/me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Consultar la última ubicación GPS registrada del técnico autenticado',
  })
  @ApiResponse({ status: 200, description: 'Coordenadas del trabajador' })
  @ApiResponse({ status: 404, description: 'Perfil de trabajador no encontrado' })
  async getMyWorkerLocation(@CurrentUser() user: { id: string }) {
    return this.locationService.getWorkerLocation(user.id);
  }
}
