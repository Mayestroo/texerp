import { IsBoolean } from 'class-validator';

export class FinalizePeriodDto {
  @IsBoolean()
  confirmed!: boolean;
}
