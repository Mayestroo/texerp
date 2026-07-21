import { IsString, Length } from 'class-validator';

export class SuspendTenantDto {
  @IsString()
  @Length(1, 1000)
  reason!: string;
}
