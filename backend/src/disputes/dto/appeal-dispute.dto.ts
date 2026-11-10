import { IsNotEmpty, IsString } from 'class-validator';

export class AppealDisputeDto {
  @IsNotEmpty()
  @IsString()
  appealReason: string;

  @IsNotEmpty()
  @IsString()
  newEvidence: string;
}

