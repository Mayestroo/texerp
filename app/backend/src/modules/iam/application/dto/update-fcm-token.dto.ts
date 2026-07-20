import { IsIn, IsOptional, IsString } from 'class-validator';

export class UpdateFcmTokenDto {
  @IsString()
  fcm_token!: string;

  @IsOptional()
  @IsIn(['ANDROID', 'IOS'])
  platform?: 'ANDROID' | 'IOS';
}
