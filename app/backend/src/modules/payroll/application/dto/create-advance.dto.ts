import { IsInt, IsOptional, IsString, IsUUID, Matches, MaxLength, Min } from 'class-validator';

export class CreateAdvanceDto {
  @IsUUID()
  worker_id!: string;

  @IsInt()
  @Min(1)
  amount!: number;

  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  given_date!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
