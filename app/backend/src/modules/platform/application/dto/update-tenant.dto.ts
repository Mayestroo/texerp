import {
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  Length,
  Matches,
} from 'class-validator';

export class UpdateTenantDto {
  @IsOptional()
  @IsString()
  @Length(2, 255)
  name?: string;

  @IsOptional()
  @IsString()
  @Length(1, 255)
  legal_name?: string;

  @IsOptional()
  @IsEmail()
  contact_email?: string;

  @IsOptional()
  @Matches(/^\+998\d{9}$/)
  contact_phone?: string;

  @IsOptional()
  @IsString()
  @Length(2, 2)
  country?: string;

  @IsOptional()
  @IsString()
  timezone?: string;

  @IsOptional()
  @IsIn(['uz', 'ru', 'uz_ru'])
  language?: 'uz' | 'ru' | 'uz_ru';

  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;
}
