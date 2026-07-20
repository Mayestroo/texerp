import { Transform } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class ProductionReportQueryDto {
  @IsDateString()
  date_from!: string;

  @IsDateString()
  date_to!: string;

  @IsIn(['worker', 'operation', 'date', 'foreman'])
  group_by!: 'worker' | 'operation' | 'date' | 'foreman';

  @IsOptional()
  @IsUUID()
  worker_id?: string;

  @IsOptional()
  @IsUUID()
  foreman_id?: string;

  @IsOptional()
  @IsUUID()
  operation_id?: string;

  @IsOptional()
  @IsUUID()
  department_id?: string;

  @IsOptional()
  @Transform(({ value }) =>
    value !== undefined ? Number(value) : undefined,
  )
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Transform(({ value }) =>
    value !== undefined ? Number(value) : undefined,
  )
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}
