import { IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class CorrectApproveEntryDto {
  @IsInt()
  @Min(1)
  corrected_quantity!: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  correction_comment?: string;
}
