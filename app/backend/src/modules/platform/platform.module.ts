import { Module } from '@nestjs/common';
import { PlatformDatabase } from '../../infrastructure/database/platform-database';
import { PlatformAuthService } from './application/platform-auth.service';
import { TenantsService } from './application/tenants.service';
import { PlansService } from './application/plans.service';
import { FeatureFlagsService } from './application/feature-flags.service';
import { PlatformHealthService } from './application/platform-health.service';
import { ImpersonationService } from './application/impersonation.service';
import { PlatformJwtAuthGuard } from './presentation/platform-jwt.guard';
import { PlatformExceptionFilter } from './presentation/platform-exception.filter';
import { PlatformAuthController } from './presentation/platform-auth.controller';
import { PlatformTenantsController } from './presentation/platform-tenants.controller';
import { PlatformPlansController } from './presentation/platform-plans.controller';
import { PlatformFeaturesController } from './presentation/platform-features.controller';
import { PlatformHealthController } from './presentation/platform-health.controller';
import { PlatformImpersonationController } from './presentation/platform-impersonation.controller';

@Module({
  controllers: [
    PlatformAuthController,
    PlatformTenantsController,
    PlatformPlansController,
    PlatformFeaturesController,
    PlatformHealthController,
    PlatformImpersonationController,
  ],
  providers: [
    PlatformDatabase,
    PlatformAuthService,
    TenantsService,
    PlansService,
    FeatureFlagsService,
    PlatformHealthService,
    ImpersonationService,
    PlatformJwtAuthGuard,
    PlatformExceptionFilter,
  ],
  exports: [PlatformDatabase],
})
export class PlatformModule {}
