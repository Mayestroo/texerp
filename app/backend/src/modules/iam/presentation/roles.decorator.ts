import { SetMetadata } from '@nestjs/common';
import { AccessTokenClaims } from '../application/access-token-claims';

export const ROLES_KEY = 'roles';

export const Roles = (
  ...roles: AccessTokenClaims['role'][]
): MethodDecorator & ClassDecorator => SetMetadata(ROLES_KEY, roles);
