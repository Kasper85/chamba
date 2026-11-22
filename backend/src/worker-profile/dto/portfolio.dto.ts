import { IsString, IsNotEmpty, MaxLength, Matches } from 'class-validator';
export class PortfolioDto {
  @IsString() @IsNotEmpty() @MaxLength(120) title: string;
  @IsString() @MaxLength(100) category: string;
  @IsString() @MaxLength(600) beforeDescription: string;
  @IsString() @MaxLength(600) afterDescription: string;
  @IsString() @MaxLength(700000) @Matches(/^data:image\/jpeg;base64,[A-Za-z0-9+/]+=*$/) beforeImageUrl: string;
  @IsString() @MaxLength(700000) @Matches(/^data:image\/jpeg;base64,[A-Za-z0-9+/]+=*$/) afterImageUrl: string;
}
