import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { createHash } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { UserType } from '@prisma/client';
import {
  AdminLoginDto,
  RequestOtpDto,
  VerifyOtpDto,
} from './dto/auth.dto';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
  ) {}

  async requestOtp(dto: RequestOtpDto) {
    const phone = this.normalizePhone(dto.phoneNumber);
    const mockCode = this.config.get('OTP_MOCK_CODE', '123456');
    const expiry = Number(this.config.get('OTP_EXPIRY_SECONDS', 300));
    const codeHash = await bcrypt.hash(mockCode, 8);

    await this.prisma.otpCode.create({
      data: {
        phoneNumber: phone,
        codeHash,
        expiresAt: new Date(Date.now() + expiry * 1000),
      },
    });

    // Mock SMS provider — log OTP for local development
    this.logger.log(`[MOCK OTP] ${phone} => ${mockCode}`);

    return {
      message: 'OTP sent',
      expiresInSeconds: expiry,
      mockHint:
        this.config.get('NODE_ENV') === 'development'
          ? `Use code ${mockCode}`
          : undefined,
    };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const phone = this.normalizePhone(dto.phoneNumber);
    const maxAttempts = Number(this.config.get('OTP_MAX_ATTEMPTS', 5));

    const otp = await this.prisma.otpCode.findFirst({
      where: { phoneNumber: phone, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) {
      throw new UnauthorizedException({
        code: 'OTP_INVALID',
        message: 'No OTP found. Request a new one.',
      });
    }
    if (otp.expiresAt < new Date()) {
      throw new UnauthorizedException({
        code: 'OTP_EXPIRED',
        message: 'OTP expired',
      });
    }
    if (otp.attempts >= maxAttempts) {
      throw new UnauthorizedException({
        code: 'OTP_INVALID',
        message: 'Too many attempts',
      });
    }

    const ok = await bcrypt.compare(dto.code, otp.codeHash);
    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { attempts: otp.attempts + 1, consumedAt: ok ? new Date() : null },
    });

    if (!ok) {
      throw new UnauthorizedException({
        code: 'OTP_INVALID',
        message: 'Invalid OTP',
      });
    }

    const userType = (dto.userType || 'PASSENGER') as UserType;
    let user = await this.prisma.user.findUnique({ where: { phoneNumber: phone } });

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          phoneNumber: phone,
          userType,
          phoneVerifiedAt: new Date(),
          ...(userType === 'PASSENGER'
            ? { passengerProfile: { create: {} } }
            : {}),
          ...(userType === 'DRIVER'
            ? {
                driverProfile: {
                  create: {
                    wallet: { create: {} },
                  },
                },
              }
            : {}),
        },
      });
    } else {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { phoneVerifiedAt: new Date() },
      });
      if (userType === 'PASSENGER') {
        await this.prisma.passengerProfile.upsert({
          where: { userId: user.id },
          create: { userId: user.id },
          update: {},
        });
      }
      if (userType === 'DRIVER') {
        const dp = await this.prisma.driverProfile.upsert({
          where: { userId: user.id },
          create: { userId: user.id },
          update: {},
        });
        await this.prisma.driverWallet.upsert({
          where: { driverId: dp.id },
          create: { driverId: dp.id },
          update: {},
        });
      }
    }

    return this.issueTokens(user.id, user.phoneNumber, user.userType);
  }

  async adminLogin(dto: AdminLoginDto) {
    const phone = this.normalizePhone(dto.phoneNumber);
    const user = await this.prisma.user.findUnique({
      where: { phoneNumber: phone },
      include: { adminProfile: true },
    });

    if (!user || user.userType !== 'ADMIN' || !user.passwordHash) {
      throw new UnauthorizedException({
        code: 'UNAUTHORIZED',
        message: 'Invalid credentials',
      });
    }

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException({
        code: 'UNAUTHORIZED',
        message: 'Invalid credentials',
      });
    }

    return this.issueTokens(user.id, user.phoneNumber, user.userType, [
      user.adminProfile?.role || 'OPERATIONS',
    ]);
  }

  async refresh(refreshToken: string) {
    const hash = this.hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findFirst({
      where: { tokenHash: hash, revokedAt: null },
      include: { user: { include: { adminProfile: true } } },
    });
    if (!stored || stored.expiresAt < new Date()) {
      throw new UnauthorizedException({
        code: 'UNAUTHORIZED',
        message: 'Invalid refresh token',
      });
    }

    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });

    const roles =
      stored.user.userType === 'ADMIN'
        ? [stored.user.adminProfile?.role || 'OPERATIONS']
        : undefined;

    return this.issueTokens(
      stored.user.id,
      stored.user.phoneNumber,
      stored.user.userType,
      roles,
    );
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        passengerProfile: true,
        driverProfile: {
          include: {
            wallet: true,
            location: true,
            assignments: { where: { active: true }, include: { vehicle: true } },
          },
        },
        adminProfile: true,
      },
    });
    if (!user) {
      throw new BadRequestException({ code: 'NOT_FOUND', message: 'User not found' });
    }
    const { passwordHash: _, ...safe } = user;
    return safe;
  }

  private async issueTokens(
    userId: string,
    phoneNumber: string,
    userType: string,
    roles?: string[],
  ) {
    const payload = { sub: userId, phoneNumber, userType, roles };
    const accessToken = await this.jwt.signAsync(payload, {
      secret: this.config.get('JWT_ACCESS_SECRET'),
      expiresIn: this.config.get('JWT_ACCESS_EXPIRES_IN', '15m'),
    });
    const refreshToken = await this.jwt.signAsync(
      { sub: userId, type: 'refresh' },
      {
        secret: this.config.get('JWT_REFRESH_SECRET'),
        expiresIn: this.config.get('JWT_REFRESH_EXPIRES_IN', '30d'),
      },
    );

    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: this.hashToken(refreshToken),
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      },
    });

    return {
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: this.config.get('JWT_ACCESS_EXPIRES_IN', '15m'),
      user: { id: userId, phoneNumber, userType, roles },
    };
  }

  private normalizePhone(phone: string) {
    let p = phone.trim().replace(/\s+/g, '');
    if (p.startsWith('0')) p = '+94' + p.slice(1);
    if (!p.startsWith('+')) p = '+' + p;
    return p;
  }

  private hashToken(token: string) {
    return createHash('sha256').update(token).digest('hex');
  }
}
