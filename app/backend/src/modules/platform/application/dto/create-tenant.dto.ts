import {
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
} from 'class-validator';

export class CreateTenantDto {
  @IsString()
  @Length(2, 255)
  name!: string;

  @IsString()
  @Length(1, 100)
  @Matches(/^[a-z0-9-]+$/)
  slug!: string;

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

  @IsString()
  @Length(2, 255)
  director_full_name!: string;

  @Matches(/^\+998\d{9}$/)
  director_phone!: string;

  @Matches(/^\d{4}$/)
  director_initial_pin!: string;

  @IsOptional()
  @IsUUID()
  plan_id?: string;
}
