import {
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class UpdateOperationDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  name?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  code?: string | null;

  @IsOptional()
  @IsInt()
  @Min(1)
  unit_price?: number;

  @IsOptional()
  @IsInt()
  sort_order?: number;
}
