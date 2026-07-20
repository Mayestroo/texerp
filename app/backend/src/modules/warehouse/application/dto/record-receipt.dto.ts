import {
  IsArray,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export class RecordReceiptDto {
  @IsNumber()
  @Min(0.001)
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
  @IsString({ each: true })
  @MaxLength(2048, { each: true })
  photo_urls?: string[];
}
