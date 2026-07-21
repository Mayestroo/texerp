import {
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class RecordCorrectionDto {
  @IsIn(['POSITIVE', 'NEGATIVE'])
  correction_type!: 'POSITIVE' | 'NEGATIVE';

  @IsNumber()
  @Min(0.001)
  @Max(99999999999.999)
  quantity!: number;

  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  movement_date!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  correction_reason!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  note?: string;
}
