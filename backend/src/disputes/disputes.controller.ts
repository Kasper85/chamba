import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { DisputesService } from './disputes.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { RolesGuard } from '../auth/guards/roles.guard.js';
import { Roles } from '../auth/decorators/roles.decorator.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { OpenDisputeDto } from './dto/open-dispute.dto.js';
import { ResolveDisputeDto } from './dto/resolve-dispute.dto.js';
import { AppealDisputeDto } from './dto/appeal-dispute.dto.js';

@ApiTags('Disputes & Support')
@Controller('disputes')
export class DisputesController {
  constructor(private readonly disputesService: DisputesService) {}

  @Post('jobs/:jobId/open')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Abrir una disputa formal para una chamba (§5, §8 L7)',
    description: 'Congela los fondos en custodia pasando el trabajo a EN_DISPUTA y genera un ticket de soporte.',
  })
  @ApiResponse({ status: 201, description: 'Disputa abierta y fondos congelados' })
  async openDispute(
    @CurrentUser() user: { id: string },
    @Param('jobId') jobId: string,
    @Body() dto: OpenDisputeDto,
  ) {
    return this.disputesService.openDispute(user.id, jobId, dto);
  }

  @Post(':id/recommendation')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPPORT', 'ADMIN')
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Generar recomendación de IA para soporte (§5, §8 L7, §8 L12)',
    description: 'La IA analiza evidencias y recomienda veredicto con confianza y justificación. Exclusivo para operadores de soporte no involucrados.',
  })
  async generateAiRecommendation(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
  ) {
    return this.disputesService.generateAiRecommendation(id, user.id);
  }

  @Post(':id/resolve')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPPORT', 'ADMIN')
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Resolución de disputa por operador humano de soporte (§5, §8 L7, §8 L12)',
    description: 'Soporte aprueba con un clic (liberar / reembolsar / dividir). Ninguna parte involucrada puede resolver su propia disputa.',
  })
  async resolveDispute(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: ResolveDisputeDto,
  ) {
    return this.disputesService.resolveDispute(user.id, id, dto);
  }

  @Post(':id/appeal')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Apelación de resolución con evidencia nueva (máximo 1)',
  })
  async appealDispute(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: AppealDisputeDto,
  ) {
    return this.disputesService.appealDispute(user.id, id, dto);
  }

  @Get('jobs/:jobId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Consultar estado, resolución y liquidación contable de disputa por jobId (§5, §8 L14)' })
  async getDisputeByJobId(
    @CurrentUser() user: { id: string; role?: string },
    @Param('jobId') jobId: string,
  ) {
    return this.disputesService.getDisputeByJobId(jobId, user);
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Consultar detalle de disputa por disputeId con auditoría (§5, §8 L14)' })
  async getDisputeById(
    @CurrentUser() user: { id: string; role?: string },
    @Param('id') id: string,
  ) {
    return this.disputesService.getDisputeById(id, user);
  }
}

