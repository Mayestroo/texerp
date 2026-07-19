import { IsIn, IsInt, IsString, IsUUID, MaxLength, Min, MinLength } from 'class-validator';

export class CreateAdjustmentDto {
  @IsUUID()
  worker_id!: string;

  @IsIn(['BONUS', 'DEDUCTION'])
  type!: 'BONUS' | 'DEDUCTION';

  @IsInt()
  @Min(1)
  amount!: number;

  @IsString()
  @MinLength(1)
  @MaxLength(500)
  reason!: string;
}
