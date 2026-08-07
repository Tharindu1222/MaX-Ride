# MaX Ride — Shared Types

export type UserType = 'PASSENGER' | 'DRIVER' | 'ADMIN';

export type AccountStatus = 'ACTIVE' | 'SUSPENDED' | 'DELETED';

export type RideStatus =
  | 'REQUESTED'
  | 'SEARCHING'
  | 'DRIVER_OFFERED'
  | 'DRIVER_ASSIGNED'
  | 'DRIVER_ARRIVED'
  | 'TRIP_STARTED'
  | 'TRIP_COMPLETED'
  | 'CANCELLED_BY_PASSENGER'
  | 'CANCELLED_BY_DRIVER'
  | 'CANCELLED_BY_SYSTEM'
  | 'NO_DRIVERS_AVAILABLE'
  | 'PAYMENT_PENDING'
  | 'PAYMENT_FAILED';

export type DriverOperationalStatus =
  | 'OFFLINE'
  | 'ONLINE'
  | 'BUSY'
  | 'ON_TRIP';

export type DriverApprovalStatus =
  | 'DRAFT'
  | 'SUBMITTED'
  | 'UNDER_REVIEW'
  | 'APPROVED'
  | 'REJECTED'
  | 'SUSPENDED';

export type PaymentMethod = 'CASH' | 'CARD';

export type PaymentStatus =
  | 'PENDING'
  | 'AUTHORIZED'
  | 'CAPTURED'
  | 'FAILED'
  | 'REFUNDED'
  | 'CASH_COLLECTED';

export type CurrencyCode = 'LKR';

export const CURRENCY: CurrencyCode = 'LKR';
export const PLATFORM_NAME = 'MaX Ride';
export const DEFAULT_COUNTRY = 'LK';

export const ERROR_CODES = {
  UNAUTHORIZED: 'UNAUTHORIZED',
  FORBIDDEN: 'FORBIDDEN',
  NOT_FOUND: 'NOT_FOUND',
  VALIDATION_FAILED: 'VALIDATION_FAILED',
  OTP_INVALID: 'OTP_INVALID',
  OTP_EXPIRED: 'OTP_EXPIRED',
  RIDE_NOT_FOUND: 'RIDE_NOT_FOUND',
  RIDE_INVALID_STATE: 'RIDE_INVALID_STATE',
  NO_DRIVERS_AVAILABLE: 'NO_DRIVERS_AVAILABLE',
  DRIVER_NOT_ELIGIBLE: 'DRIVER_NOT_ELIGIBLE',
  OFFER_EXPIRED: 'OFFER_EXPIRED',
  PIN_INVALID: 'PIN_INVALID',
  PAYMENT_FAILED: 'PAYMENT_FAILED',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
} as const;

export interface ApiSuccessResponse<T> {
  success: true;
  data: T;
  meta?: Record<string, unknown>;
}

export interface ApiErrorResponse {
  success: false;
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
}
