import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsNotEmpty, IsNumber, IsObject, IsOptional, IsString, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class PaymentWebhookDataDto {
  @ApiProperty({ example: 'chr_live_98124871239' })
  @IsNotEmpty()
  @IsString()
  transactionId: string;

  @ApiProperty({ example: 'user-client-1' })
  @IsNotEmpty()
  @IsString()
  userId: string;

  @ApiProperty({ example: 75.0 })
  @IsNotEmpty()
  @Type(() => Number)
  @IsNumber()
  @Min(0.5)
  amount: number;

  @ApiPropertyOptional({ example: 'PEN', default: 'PEN' })
  @IsOptional()
  @IsString()
  currency?: string;

  @ApiPropertyOptional({ example: 'job-101' })
  @IsOptional()
  @IsString()
  jobRequestId?: string;

  @ApiPropertyOptional({ example: true, description: 'Si es true, retiene los fondos inmediatamente en Escrow para la solicitud' })
  @IsOptional()
  @IsBoolean()
  autoHoldEscrow?: boolean;
}

export class PaymentWebhookDto {
  @ApiProperty({ example: 'payment.succeeded' })
  @IsNotEmpty()
  @IsString()
  event: string;

  @ApiProperty({ type: PaymentWebhookDataDto })
  @IsNotEmpty()
  @IsObject()
  @ValidateNested()
  @Type(() => PaymentWebhookDataDto)
  data: PaymentWebhookDataDto;
}
