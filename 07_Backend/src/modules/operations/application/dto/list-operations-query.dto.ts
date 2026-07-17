import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class ListOperationsQueryDto {
  @IsOptional()
  @IsIn(['ACTIVE', 'INACTIVE', 'ALL'])
  status: 'ACTIVE' | 'INACTIVE' | 'ALL' = 'ACTIVE';

  @IsOptional()
  @IsString()
  @MaxLength(255)
  search?: string;
}
