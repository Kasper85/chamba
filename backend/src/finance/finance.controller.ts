import { Body, Controller, Get, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { FinanceService } from './finance.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { HoldEscrowDto } from './dto/hold-escrow.dto.js';
import { ReleaseEscrowDto } from './dto/release-escrow.dto.js';
import { DepositWalletDto } from './dto/deposit-wallet.dto.js';

@ApiTags('Finance & Escrow (FinTech)')
@Controller('finance')
export class FinanceController {
  constructor(private readonly financeService: FinanceService) {}

  @Get('wallet')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Consultar saldo y Libro Mayor inmutable del usuario autenticado',
    description:
      'Calcula el saldo disponible y saldo en custodia sumando estrictamente las entradas del Ledger inmutable.',
  })
  @ApiResponse({ status: 200, description: 'Resumen financiero de la billetera' })
  async getMyWallet(@CurrentUser() user: { id: string }) {
    return this.financeService.getWalletSummary(user.id);
  }

  @Post('escrow/hold')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Retener fondos en Escrow cuando el cliente acepta una propuesta',
    description:
      'Ejecuta una transacción ACID con SELECT FOR UPDATE para retener los fondos de forma segura.',
  })
  @ApiResponse({ status: 201, description: 'Fondos retenidos en custodia exitosamente' })
  @ApiResponse({ status: 400, description: 'Saldo insuficiente en billetera' })
  @ApiResponse({ status: 409, description: 'Ya existe retención activa para este trabajo' })
  async holdEscrow(
    @CurrentUser() user: { id: string },
    @Body() dto: HoldEscrowDto,
  ) {
    return this.financeService.holdFundsInEscrow(
      user.id,
      dto.jobRequestId,
      dto.amount,
      dto.description,
    );
  }

  @Post('escrow/release')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Liberar fondos retenidos en Escrow al técnico tras confirmar culminación del trabajo',
    description:
      'Acredita el pago en la billetera del técnico y cierra el ciclo de custodia de forma transaccional.',
  })
  @ApiResponse({ status: 200, description: 'Fondos liberados exitosamente al técnico' })
  @ApiResponse({ status: 404, description: 'No se encontraron fondos retenidos para esta solicitud' })
  @ApiResponse({ status: 409, description: 'Fondos ya liberados previamente' })
  async releaseEscrow(
    @CurrentUser() user: { id: string },
    @Body() dto: ReleaseEscrowDto,
  ) {
    return this.financeService.releaseEscrow(
      user.id,
      dto.workerUserId,
      dto.jobRequestId,
      dto.amount,
    );
  }

  @Post('deposit')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Acreditar fondos directamente a la billetera (recarga de saldo)',
  })
  @ApiResponse({ status: 201, description: 'Fondos acreditados en el Libro Mayor' })
  async deposit(
    @CurrentUser() user: { id: string },
    @Body() dto: DepositWalletDto,
  ) {
    return this.financeService.depositFunds(
      user.id,
      dto.amount,
      dto.description,
      dto.jobRequestId,
    );
  }
}
