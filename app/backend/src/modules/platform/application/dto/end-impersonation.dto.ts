import { IsUUID } from 'class-validator';

export class EndImpersonationDto {
  @IsUUID()
  jti!: string;
}
