import { IsInt, IsNumber, IsOptional, Max, Min } from 'class-validator';

export class UpdateSettingsDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(7)
  back_date_window_days?: number;

  @IsOptional()
  @IsNumber()
  @Min(0.01)
  suspicious_quantity_multiplier?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  payroll_min_pay?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  duplicate_window_minutes?: number;
}
