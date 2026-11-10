import { IsNotEmpty, IsString } from 'class-validator';

export class OpenDisputeDto {
  @IsNotEmpty()
  @IsString()
  reason: string;

  @IsNotEmpty()
  @IsString()
  statement: string;
}

