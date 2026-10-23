import { IsNotEmpty, IsString } from 'class-validator';

export class JoinJobRoomDto {
  @IsNotEmpty({ message: 'El ID de la solicitud (jobRequestId) es obligatorio' })
  @IsString()
  jobRequestId: string;
}
