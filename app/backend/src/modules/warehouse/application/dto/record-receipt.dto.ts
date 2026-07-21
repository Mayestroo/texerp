import {
  IsArray,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUrl,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class RecordReceiptDto {
  @IsNumber()
  @Min(0.001)
  @Max(99999999999.999)
  quantity!: number;

  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  movement_date!: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  supplier_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  note?: string;

  @IsOptional()
  @IsArray()
  @IsUrl({ require_protocol: true }, { each: true })
  @MaxLength(2048, { each: true })
  photo_urls?: string[];
}
