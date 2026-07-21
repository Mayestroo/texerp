import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';
import { PlatformAccessTokenClaims } from '../application/platform-access-token-claims';
import { PlatformAuthService } from '../application/platform-auth.service';

export interface AuthenticatedPlatformRequest extends Request {
  user: PlatformAccessTokenClaims;
}

@Injectable()
export class PlatformJwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly platformAuthService: PlatformAuthService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const [scheme, token] = request.get('authorization')?.split(' ') ?? [];

    if (scheme !== 'Bearer' || !token) {
      throw new UnauthorizedException();
    }

    try {
      const claims =
        await this.jwtService.verifyAsync<PlatformAccessTokenClaims>(token);
      if (
        !claims.sub ||
        claims.tenant_id !== null ||
        claims.role !== 'SUPER_ADMIN' ||
        claims.token_use !== 'platform' ||
        !claims.jti ||
        !claims.sid ||
        !claims.email ||
        !(await this.platformAuthService.validateAccessSession(claims))
      ) {
        throw new UnauthorizedException();
      }
      (request as AuthenticatedPlatformRequest).user = claims;
      return true;
    } catch {
      throw new UnauthorizedException();
    }
  }
}
