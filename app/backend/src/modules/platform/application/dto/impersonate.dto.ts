import { IsUUID } from 'class-validator';

export class ImpersonateDto {
  @IsUUID()
  user_id!: string;
}
