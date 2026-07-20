import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateOperationEntryDto {
  @IsUUID()
  operation_id!: string;

  @IsInt()
  @Min(1)
  @Max(9_999)
  quantity!: number;

  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  record_date!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  worker_note?: string;
}
