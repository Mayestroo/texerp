import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { AuthService } from './application/auth.service';
import { AuthController } from './presentation/auth.controller';
import { JwtAuthGuard } from './presentation/jwt-auth.guard';
import { UsersService } from './application/users.service';
import { RolesGuard } from './presentation/roles.guard';
import { UsersController } from './presentation/users.controller';
import { UserExceptionFilter } from './presentation/user-exception.filter';

@Module({
  imports: [
    JwtModule.registerAsync({
      global: true,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        privateKey: Buffer.from(
          config.getOrThrow<string>('JWT_PRIVATE_KEY_BASE64'),
          'base64',
        ).toString('utf8'),
        publicKey: Buffer.from(
          config.getOrThrow<string>('JWT_PUBLIC_KEY_BASE64'),
          'base64',
        ).toString('utf8'),
        signOptions: { algorithm: 'RS256' as const, expiresIn: 900 },
        verifyOptions: { algorithms: ['RS256' as const] },
      }),
    }),
  ],
  controllers: [AuthController, UsersController],
  providers: [
    AuthService,
    UsersService,
    JwtAuthGuard,
    RolesGuard,
    UserExceptionFilter,
  ],
  exports: [AuthService, JwtAuthGuard, RolesGuard],
})
export class IamModule {}
