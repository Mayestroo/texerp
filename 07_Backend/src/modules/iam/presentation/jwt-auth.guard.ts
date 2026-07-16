import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';
import { AccessTokenClaims } from '../application/access-token-claims';
import { AuthService } from '../application/auth.service';

export interface AuthenticatedRequest extends Request {
  user: AccessTokenClaims;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly authService: AuthService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const [scheme, token] = request.get('authorization')?.split(' ') ?? [];

    if (scheme !== 'Bearer' || !token) {
      throw new UnauthorizedException();
    }

    try {
      const claims =
        await this.jwtService.verifyAsync<AccessTokenClaims>(token);
      if (
        !claims.sub ||
        !claims.tenant_id ||
        !claims.jti ||
        !claims.sid ||
        !claims.phone ||
        !['WORKER', 'FOREMAN', 'ACCOUNTANT', 'DIRECTOR'].includes(
          claims.role,
        ) ||
        !(await this.authService.validateAccessSession(claims))
      ) {
        throw new UnauthorizedException();
      }
      (request as AuthenticatedRequest).user = claims;
      return true;
    } catch {
      throw new UnauthorizedException();
    }
  }
}
