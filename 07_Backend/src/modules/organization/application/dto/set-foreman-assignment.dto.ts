import { IsUUID } from 'class-validator';

export class SetForemanAssignmentDto {
  @IsUUID()
  department_id!: string;
}
