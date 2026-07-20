import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RejectEntryDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  reason!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  foreman_note?: string;
}
