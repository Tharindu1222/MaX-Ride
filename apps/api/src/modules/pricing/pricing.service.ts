import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { distanceMeters, estimateDurationSeconds, roundMoney } from '../../common/utils/geo.util';
import { ServiceType } from '@prisma/client';

export interface FareEstimateInput {
  vehicleCategoryId: string;
  pickupLat: number;
  pickupLng: number;
  dropoffLat?: number;
  dropoffLng?: number;
  promoCode?: string;
  serviceType?: ServiceType;
  rentalPackageId?: string;
}

@Injectable()
export class PricingService {
  constructor(private prisma: PrismaService) {}

  async listCategories(serviceType: ServiceType = ServiceType.RIDE) {
    return this.prisma.vehicleCategory.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      include: {
        pricingRules: {
          where: { isActive: true, serviceType },
          take: 1,
        },
      },
    });
  }

  async listRentalPackages() {
    return this.prisma.rentalPackage.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      include: { category: true },
    });
  }

  async estimate(input: FareEstimateInput) {
    const serviceType = input.serviceType ?? ServiceType.RIDE;

    if (serviceType === ServiceType.RENTAL) {
      if (!input.rentalPackageId) {
        throw new BadRequestException('rentalPackageId is required for RENTAL');
      }
      const pkg = await this.prisma.rentalPackage.findFirst({
        where: { id: input.rentalPackageId, isActive: true },
        include: { category: true },
      });
      if (!pkg) throw new NotFoundException('Rental package not found');

      const categoryId = input.vehicleCategoryId || pkg.vehicleCategoryId;
      if (!categoryId) {
        throw new BadRequestException('vehicleCategoryId is required');
      }

      let distM = 0;
      let durationS = (pkg.durationHours ?? 1) * 3600;
      if (
        input.dropoffLat != null &&
        input.dropoffLng != null &&
        pkg.packageType === 'FIXED_TRIP'
      ) {
        distM = distanceMeters(
          input.pickupLat,
          input.pickupLng,
          input.dropoffLat,
          input.dropoffLng,
        );
        durationS = estimateDurationSeconds(distM);
      }

      let discount = 0;
      const price = Number(pkg.price);
      if (input.promoCode) {
        discount = await this.computePromoDiscount(input.promoCode, price);
      }

      return {
        serviceType,
        rentalPackageId: pkg.id,
        packageName: pkg.name,
        packageType: pkg.packageType,
        vehicleCategoryId: categoryId,
        categoryName: pkg.category?.name ?? 'Rental',
        currency: pkg.currency,
        estimatedDistanceMeters: Math.round(distM),
        estimatedDurationSeconds: durationS,
        baseFare: roundMoney(price),
        distanceFare: 0,
        timeFare: 0,
        bookingFee: 0,
        surgeMultiplier: 1,
        discountAmount: roundMoney(discount),
        estimatedFare: roundMoney(Math.max(0, price - discount)),
        minimumFare: price,
      };
    }

    const rule = await this.prisma.pricingRule.findFirst({
      where: {
        vehicleCategoryId: input.vehicleCategoryId,
        serviceType,
        isActive: true,
      },
      include: { category: true },
    });
    if (!rule) {
      throw new NotFoundException({
        code: 'NOT_FOUND',
        message: `Pricing rule not found for category (${serviceType})`,
      });
    }

    if (input.dropoffLat == null || input.dropoffLng == null) {
      throw new BadRequestException('dropoff is required for this service');
    }

    const distM = distanceMeters(
      input.pickupLat,
      input.pickupLng,
      input.dropoffLat,
      input.dropoffLng,
    );
    const durationS = estimateDurationSeconds(distM);
    const km = distM / 1000;
    const minutes = durationS / 60;

    const base = Number(rule.baseFare);
    const distanceFare = km * Number(rule.perKmFare);
    const timeFare = minutes * Number(rule.perMinuteFare);
    const bookingFee = Number(rule.bookingFee);
    const surge = Number(rule.surgeMultiplier);

    let subtotal = (base + distanceFare + timeFare) * surge + bookingFee;
    subtotal = Math.max(subtotal, Number(rule.minimumFare));

    let discount = 0;
    if (input.promoCode) {
      discount = await this.computePromoDiscount(input.promoCode, subtotal);
    }

    const estimatedFare = roundMoney(Math.max(0, subtotal - discount));

    return {
      serviceType,
      vehicleCategoryId: input.vehicleCategoryId,
      categoryName: rule.category.name,
      currency: rule.currency,
      estimatedDistanceMeters: Math.round(distM),
      estimatedDurationSeconds: durationS,
      baseFare: roundMoney(base),
      distanceFare: roundMoney(distanceFare),
      timeFare: roundMoney(timeFare),
      bookingFee: roundMoney(bookingFee),
      surgeMultiplier: surge,
      discountAmount: roundMoney(discount),
      estimatedFare,
      minimumFare: Number(rule.minimumFare),
    };
  }

  async computeFinalFare(params: {
    vehicleCategoryId: string;
    distanceMeters: number;
    durationSeconds: number;
    waitingMinutes?: number;
    promoCode?: string;
    serviceType?: ServiceType;
    rentalPackageId?: string;
  }) {
    if (params.serviceType === ServiceType.RENTAL && params.rentalPackageId) {
      const pkg = await this.prisma.rentalPackage.findUnique({
        where: { id: params.rentalPackageId },
      });
      if (!pkg) throw new BadRequestException('Rental package missing');
      let discount = 0;
      const price = Number(pkg.price);
      if (params.promoCode) {
        discount = await this.computePromoDiscount(params.promoCode, price);
      }
      return {
        finalFare: roundMoney(Math.max(0, price - discount)),
        bookingFee: 0,
        waitingFee: 0,
        discountAmount: roundMoney(discount),
        surgeMultiplier: 1,
      };
    }

    const serviceType = params.serviceType ?? ServiceType.RIDE;
    const rule = await this.prisma.pricingRule.findFirst({
      where: {
        vehicleCategoryId: params.vehicleCategoryId,
        serviceType,
        isActive: true,
      },
    });
    if (!rule) throw new BadRequestException('Pricing rule missing');

    const km = params.distanceMeters / 1000;
    const minutes = params.durationSeconds / 60;
    const waiting = (params.waitingMinutes || 0) * Number(rule.waitingPerMinute);
    const surge = Number(rule.surgeMultiplier);

    let subtotal =
      (Number(rule.baseFare) +
        km * Number(rule.perKmFare) +
        minutes * Number(rule.perMinuteFare)) *
        surge +
      Number(rule.bookingFee) +
      waiting;

    subtotal = Math.max(subtotal, Number(rule.minimumFare));
    let discount = 0;
    if (params.promoCode) {
      discount = await this.computePromoDiscount(params.promoCode, subtotal);
    }

    return {
      finalFare: roundMoney(Math.max(0, subtotal - discount)),
      bookingFee: Number(rule.bookingFee),
      waitingFee: roundMoney(waiting),
      discountAmount: roundMoney(discount),
      surgeMultiplier: surge,
    };
  }

  private async computePromoDiscount(code: string, subtotal: number) {
    const promo = await this.prisma.promoCode.findFirst({
      where: {
        code: code.toUpperCase(),
        isActive: true,
        validFrom: { lte: new Date() },
        validTo: { gte: new Date() },
      },
    });
    if (!promo) return 0;
    if (promo.minFare && subtotal < Number(promo.minFare)) return 0;
    if (promo.usageLimit != null && promo.usedCount >= promo.usageLimit) return 0;

    let discount = 0;
    if (promo.discountType === 'PERCENT') {
      discount = (subtotal * Number(promo.discountValue)) / 100;
      if (promo.maxDiscount != null) {
        discount = Math.min(discount, Number(promo.maxDiscount));
      }
    } else {
      discount = Number(promo.discountValue);
    }
    return Math.min(discount, subtotal);
  }
}
