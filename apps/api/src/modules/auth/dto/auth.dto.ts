import { IsEnum, IsOptional, IsString, Matches, MinLength } from 'class-validator';

export class RequestOtpDto {
  @IsString()
  @Matches(/^\+?[0-9]{9,15}$/)
  phoneNumber!: string;

  @IsEnum(['PASSENGER', 'DRIVER', 'ADMIN'] as const)
  @IsOptional()
  userType?: 'PASSENGER' | 'DRIVER' | 'ADMIN';
}

export class VerifyOtpDto {
  @IsString()
  @Matches(/^\+?[0-9]{9,15}$/)
  phoneNumber!: string;

  @IsString()
  @MinLength(4)
  code!: string;

  @IsEnum(['PASSENGER', 'DRIVER', 'ADMIN'] as const)
  @IsOptional()
  userType?: 'PASSENGER' | 'DRIVER' | 'ADMIN';
}

export class AdminLoginDto {
  @IsString()
  phoneNumber!: string;

  @IsString()
  @MinLength(4)
  password!: string;
}

export class RefreshTokenDto {
  @IsString()
  refreshToken!: string;
}
