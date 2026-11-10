import { IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

export enum DisputeVerdict {
  RELEASE_WORKER = 'RELEASE_WORKER',
  REFUND_CLIENT = 'REFUND_CLIENT',
  SPLIT = 'SPLIT',
}

export class ResolveDisputeDto {
  @IsNotEmpty()
  @IsEnum(DisputeVerdict)
  verdict: DisputeVerdict;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(99)
  workerSplitPercent?: number;

  @IsNotEmpty()
  @IsString()
  notes: string;
}

