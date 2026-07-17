import {
  IsIn,
  IsInt,
  IsString,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class CreateOperationDto {
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  name!: string;

  @ValidateIf((_object, value) => value !== undefined)
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  code?: string;

  @IsIn(['PIECE', 'METER', 'PAIR'])
  unit!: 'PIECE' | 'METER' | 'PAIR';

  @IsInt()
  @Min(1)
  unit_price!: number;

  @ValidateIf((_object, value) => value !== undefined)
  @IsInt()
  sort_order?: number;
}
