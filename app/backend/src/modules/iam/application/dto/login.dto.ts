import { IsOptional, IsString, Matches } from 'class-validator';

export class LoginDto {
  @Matches(/^\+998\d{9}$/)
  phone!: string;

  @Matches(/^\d{4}$/)
  pin!: string;

  @IsOptional()
  @IsString()
  fcm_token?: string;
}
