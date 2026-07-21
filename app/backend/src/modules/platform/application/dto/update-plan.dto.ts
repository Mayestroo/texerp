import {
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Min,
} from 'class-validator';

export class UpdatePlanDto {
  @IsOptional()
  @IsString()
  @Length(1, 100)
  name?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  price_monthly_tiyin?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  price_annual_tiyin?: number;

  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  user_limit?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  storage_quota_gb?: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @Length(1, 100, { each: true })
  features?: string[];

  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}
