import {
  Body,
  Controller,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
  Req,
} from '@nestjs/common';
import { ApiHeader, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { FinanceService } from './finance.service.js';
import { PaymentWebhookDto } from './dto/payment-webhook.dto.js';

@ApiTags('Webhooks de Pasarela de Pagos')
@Controller('webhooks')
export class WebhooksController {
  constructor(private readonly financeService: FinanceService) {}

  @Post('payment')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Webhook de pasarela de pagos simulada (ej. Culqi, Niubiz, Stripe)',
    description:
      'Recibe notificaciones de pagos exitosos con verificación de firma criptográfica HMAC-SHA256 (cabecera x-webhook-signature).',
  })
  @ApiHeader({
    name: 'x-webhook-signature',
    description: 'Firma HMAC-SHA256 calculada con el secreto compartido',
    required: true,
  })
  @ApiResponse({ status: 200, description: 'Pago procesado y acreditado exitosamente' })
  @ApiResponse({ status: 401, description: 'Firma HMAC inválida' })
  async handlePaymentWebhook(
    @Body() dto: PaymentWebhookDto,
    @Headers('x-webhook-signature') signature: string,
    @Req() req: Request,
  ) {
    // Si express ya parseó el body a JSON, serializamos para verificar contra la firma
    const rawPayload =
      typeof req.body === 'string' ? req.body : JSON.stringify(req.body);

    return this.financeService.processPaymentWebhook(dto, rawPayload, signature);
  }
}
