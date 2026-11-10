import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { JobsService } from './jobs.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { CreateJobDto } from './dto/create-job.dto.js';
import { CreateBidDto } from './dto/create-bid.dto.js';
import { CounterBidDto } from './dto/counter-bid.dto.js';
import { FindJobsDto } from './dto/find-jobs.dto.js';
import { UpdateJobPhaseDto } from './dto/update-job-phase.dto.js';
import { CancelJobDto } from './dto/cancel-job.dto.js';
import { CreateRatingDto } from './dto/create-rating.dto.js';

@ApiTags('Jobs & Solicitudes')
@Controller('jobs')
export class JobsController {
  constructor(private readonly jobsService: JobsService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Publicar una nueva solicitud de chamba',
    description: 'Crea una solicitud en estado BUSCANDO y genera el PIN de seguridad de 4 dígitos.',
  })
  @ApiResponse({ status: 201, description: 'Chamba publicada con éxito' })
  async createJob(
    @CurrentUser() user: { id: string },
    @Body() dto: CreateJobDto,
  ) {
    return this.jobsService.createJob(user.id, dto);
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Listar solicitudes de trabajo',
    description: 'Filtra por rol (cliente o técnico) y estado.',
  })
  @ApiResponse({ status: 200, description: 'Listado de solicitudes' })
  async findAll(
    @CurrentUser() user: { id: string },
    @Query() query: FindJobsDto,
  ) {
    return this.jobsService.findAll(user.id, query);
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Obtener el detalle de una solicitud de trabajo (§3, §8 L14)',
  })
  @ApiResponse({ status: 200, description: 'Detalle de la solicitud con ofertas y privacidad aplicada' })
  @ApiResponse({ status: 404, description: 'Solicitud no encontrada' })
  async findOne(
    @CurrentUser() user: { id: string; role?: string },
    @Param('id') id: string,
  ) {
    return this.jobsService.findOne(id, user);
  }

  @Post(':id/bids')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Enviar una propuesta económica (oferta) para una chamba',
    description: 'Si la solicitud estaba en BUSCANDO, pasa automáticamente a NEGOCIANDO.',
  })
  @ApiResponse({ status: 201, description: 'Oferta registrada y emitida por Socket.IO' })
  async createBid(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: CreateBidDto,
  ) {
    return this.jobsService.createBid(user.id, id, dto);
  }

  @Post(':id/bids/:bidId/counter')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Enviar una contraoferta sobre una propuesta existente',
  })
  @ApiResponse({ status: 200, description: 'Contraoferta registrada' })
  async counterBid(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Param('bidId') bidId: string,
    @Body() dto: CounterBidDto,
  ) {
    return this.jobsService.counterBid(user.id, id, bidId, dto);
  }

  @Post(':id/bids/:bidId/accept')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Aceptar una oferta de un técnico',
    description: 'La chamba pasa a ACEPTADA con una ventana de 15 minutos para depósito de garantía.',
  })
  @ApiResponse({ status: 200, description: 'Oferta aceptada y chamba en estado ACEPTADA' })
  async acceptBid(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Param('bidId') bidId: string,
  ) {
    return this.jobsService.acceptBid(user.id, id, bidId);
  }

  @Put(':id/phase')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Avanzar fase de la chamba (ALCANCE.md §8 L4)',
    description:
      'Avanza la máquina de estados con validación de rol: EN_CAMINO, EN_SITIO, EN_EJECUCION (con PIN y foto antes) y POR_CONFIRMAR (con foto después) para el chambeador; COMPLETADA solo para el cliente.',
  })
  @ApiResponse({ status: 200, description: 'Fase de la chamba actualizada' })
  @ApiResponse({ status: 400, description: 'PIN incorrecto o fotos faltantes' })
  @ApiResponse({ status: 403, description: 'Permisos insuficientes para avanzar fase' })
  async updatePhase(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: UpdateJobPhaseDto,
  ) {
    return this.jobsService.updatePhase(user.id, id, dto);
  }

  @Post(':id/cancel')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Cancelar chamba según matriz de reglas de ALCANCE.md §4',
    description:
      'Aplica compensación (10% de P, mín S/ 5, máx S/ 20) si el técnico está en camino, reembolso total si aún no sale o el técnico se retrasa, e incidentes de reputación al técnico por cancelaciones o demoras.',
  })
  @ApiResponse({ status: 200, description: 'Chamba cancelada y reembolsos/compensaciones procesadas' })
  @ApiResponse({ status: 400, description: 'No se puede cancelar si el PIN presencial ya fue validado' })
  async cancelJob(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: CancelJobDto,
  ) {
    return this.jobsService.cancelJob(user.id, id, dto);
  }

  @Post(':id/rating')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Calificación mutua (1 a 5 estrellas + comentario) y propina opcional (§6, §8 L8)',
  })
  @ApiResponse({ status: 201, description: 'Calificación registrada' })
  async createRating(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: CreateRatingDto,
  ) {
    return this.jobsService.createRating(user.id, id, dto);
  }

  @Get(':id/receipt')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Obtener recibo formal de chamba completada (§6, §7, §8 L8, §8 L14)',
  })
  @ApiResponse({ status: 200, description: 'Recibo detallado con montos, comisión, fotos y fechas' })
  async getReceipt(
    @CurrentUser() user: { id: string; role?: string },
    @Param('id') id: string,
  ) {
    return this.jobsService.getJobReceipt(id, user);
  }
}

