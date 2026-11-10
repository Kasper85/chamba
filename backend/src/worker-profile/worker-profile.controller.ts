import { Body, Controller, Get, Post, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { WorkerProfileService } from './worker-profile.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { UpsertWorkerProfileDto } from './dto/upsert-worker-profile.dto.js';

@ApiTags('Worker Profile')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('worker-profile')
export class WorkerProfileController {
  constructor(private workerProfileService: WorkerProfileService) {}

  @Get('me')
  @ApiOperation({ summary: 'Consultar el perfil de trabajador del usuario autenticado' })
  @ApiResponse({ status: 200, description: 'Perfil de trabajador del usuario' })
  @ApiResponse({ status: 404, description: 'Perfil de trabajador no configurado todavía' })
  async getMyProfile(@CurrentUser() user: { id: string }) {
    return this.workerProfileService.findMyProfile(user.id);
  }

  @Put('me')
  @ApiOperation({ summary: 'Crear o actualizar el perfil de trabajador del usuario autenticado' })
  @ApiResponse({ status: 200, description: 'Perfil de trabajador creado o actualizado con éxito' })
  async updateMyProfile(
    @CurrentUser() user: { id: string },
    @Body() dto: UpsertWorkerProfileDto,
  ) {
    return this.workerProfileService.upsertMyProfile(user.id, dto);
  }

  @Post('me')
  @ApiOperation({ summary: 'Crear o actualizar perfil de trabajador (alias POST)' })
  @ApiResponse({ status: 200, description: 'Perfil de trabajador guardado con éxito' })
  async createMyProfile(
    @CurrentUser() user: { id: string },
    @Body() dto: UpsertWorkerProfileDto,
  ) {
    return this.workerProfileService.upsertMyProfile(user.id, dto);
  }

  @Put('me/availability')
  @ApiOperation({ summary: 'Alternar disponibilidad del chambeador (ALCANCE.md §8 L9)' })
  @ApiResponse({ status: 200, description: 'Disponibilidad actualizada con éxito' })
  async updateAvailability(
    @CurrentUser() user: { id: string },
    @Body() body: { isAvailable: boolean },
  ) {
    return this.workerProfileService.updateAvailability(user.id, body.isAvailable);
  }
}
