import { Module } from '@nestjs/common';
import { IamModule } from '../iam/iam.module';
import { DepartmentsService } from './application/departments.service';
import { ForemanAssignmentsService } from './application/foreman-assignments.service';
import { DepartmentsController } from './presentation/departments.controller';
import { ForemanAssignmentsController } from './presentation/foreman-assignments.controller';
import { OrganizationExceptionFilter } from './presentation/organization-exception.filter';

@Module({
  imports: [IamModule],
  controllers: [DepartmentsController, ForemanAssignmentsController],
  providers: [
    DepartmentsService,
    ForemanAssignmentsService,
    OrganizationExceptionFilter,
  ],
})
export class OrganizationModule {}
