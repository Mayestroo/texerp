import {
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateMaterialDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  code!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  category?: string;

  @IsIn(['METERS', 'KG', 'ROLLS', 'PIECES'])
  unit!: 'METERS' | 'KG' | 'ROLLS' | 'PIECES';

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(99999999999.999)
  min_quantity?: number;
}
