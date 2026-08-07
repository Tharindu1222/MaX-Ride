import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { distanceMeters, estimateDurationSeconds, roundMoney } from '../../common/utils/geo.util';

export interface FareEstimateInput {
  vehicleCategoryId: string;
  pickupLat: number;
  pickupLng: number;
  dropoffLat: number;
  dropoffLng: number;
  promoCode?: string;
}

@Injectable()
export class PricingService {
  constructor(private prisma: PrismaService) {}

  async listCategories() {
    return this.prisma.vehicleCategory.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      include: {
        pricingRules: { where: { isActive: true }, take: 1 },
      },
    });
  }

  async estimate(input: FareEstimateInput) {
    const rule = await this.prisma.pricingRule.findFirst({
      where: { vehicleCategoryId: input.vehicleCategoryId, isActive: true },
      include: { category: true },
    });
    if (!rule) {
      throw new NotFoundException({
        code: 'NOT_FOUND',
        message: 'Pricing rule not found for category',
      });
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
  }) {
    const rule = await this.prisma.pricingRule.findFirst({
      where: { vehicleCategoryId: params.vehicleCategoryId, isActive: true },
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

  private async computePromoDiscount(code: string, fare: number): Promise<number> {
    const promo = await this.prisma.promoCode.findFirst({
      where: {
        code: code.toUpperCase(),
        isActive: true,
        validFrom: { lte: new Date() },
        validTo: { gte: new Date() },
      },
    });
    if (!promo) return 0;
    if (promo.minFare && fare < Number(promo.minFare)) return 0;
    if (promo.usageLimit != null && promo.usedCount >= promo.usageLimit) return 0;

    let d =
      promo.discountType === 'PERCENT'
        ? (fare * Number(promo.discountValue)) / 100
        : Number(promo.discountValue);
    if (promo.maxDiscount != null) d = Math.min(d, Number(promo.maxDiscount));
    return roundMoney(d);
  }
}
