import { IsNotEmpty, IsOptional, IsString, IsBoolean } from 'class-validator';

export class CancelJobDto {
  @IsNotEmpty()
  @IsString()
  reason: string;

  @IsOptional()
  @IsBoolean()
  isWorkerDelay?: boolean;
}

