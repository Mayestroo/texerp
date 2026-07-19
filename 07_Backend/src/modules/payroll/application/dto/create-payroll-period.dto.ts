import { IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class CreatePayrollPeriodDto {
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  name!: string;

  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  start_date!: string;

  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  end_date!: string;
}
