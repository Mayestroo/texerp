import { Transform } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class ListUsersQueryDto {
  @IsOptional()
  @IsIn(['WORKER', 'FOREMAN', 'ACCOUNTANT', 'DIRECTOR'])
  role?: 'WORKER' | 'FOREMAN' | 'ACCOUNTANT' | 'DIRECTOR';

  @IsOptional()
  @IsIn(['ACTIVE', 'DEACTIVATED', 'ALL'])
  status: 'ACTIVE' | 'DEACTIVATED' | 'ALL' = 'ACTIVE';

  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' && /^\d+$/.test(value) ? Number(value) : value,
  )
  @IsInt()
  @Min(1)
  page = 1;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' && /^\d+$/.test(value) ? Number(value) : value,
  )
  @IsInt()
  @Min(1)
  @Max(200)
  limit = 50;
}
