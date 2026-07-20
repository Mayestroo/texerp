import { IsArray, IsBoolean, IsOptional, IsUUID } from 'class-validator';

export class MarkReadDto {
  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  notification_ids?: string[];

  @IsOptional()
  @IsBoolean()
  mark_all?: boolean;
}
