import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { roundMoney } from '../../common/utils/geo.util';

@Injectable()
export class WalletsService {
  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
  ) {}

  private commissionRate() {
    return Number(this.config.get('DEFAULT_COMMISSION_PERCENT', 20)) / 100;
  }

  async recordCashTrip(driverId: string, rideId: string, fare: number) {
    const commission = roundMoney(fare * this.commissionRate());
    const wallet = await this.ensureWallet(driverId);

    // Driver collected cash; platform commission reduces available (driver owes platform)
    const available = Number(wallet.availableBalance) - commission;
    const cash = Number(wallet.cashBalance) + fare;

    await this.prisma.driverWallet.update({
      where: { id: wallet.id },
      data: {
        availableBalance: available,
        cashBalance: cash,
      },
    });

    await this.prisma.walletTransaction.createMany({
      data: [
        {
          walletId: wallet.id,
          rideId,
          transactionType: 'CASH_COLLECTED',
          amount: fare,
          direction: 'CREDIT',
          balanceBefore: Number(wallet.cashBalance),
          balanceAfter: cash,
          description: 'Cash collected from passenger',
        },
        {
          walletId: wallet.id,
          rideId,
          transactionType: 'COMMISSION',
          amount: commission,
          direction: 'DEBIT',
          balanceBefore: Number(wallet.availableBalance),
          balanceAfter: available,
          description: 'Platform commission on cash trip',
        },
      ],
    });
  }

  async recordCardTrip(driverId: string, rideId: string, fare: number) {
    const commission = roundMoney(fare * this.commissionRate());
    const earning = roundMoney(fare - commission);
    const wallet = await this.ensureWallet(driverId);
    const before = Number(wallet.availableBalance);
    const after = before + earning;

    await this.prisma.driverWallet.update({
      where: { id: wallet.id },
      data: { availableBalance: after },
    });

    await this.prisma.walletTransaction.create({
      data: {
        walletId: wallet.id,
        rideId,
        transactionType: 'TRIP_EARNING',
        amount: earning,
        direction: 'CREDIT',
        balanceBefore: before,
        balanceAfter: after,
        description: `Trip earning (fare ${fare} - commission ${commission})`,
      },
    });
  }

  async adjust(
    driverId: string,
    amount: number,
    direction: 'CREDIT' | 'DEBIT',
    description: string,
  ) {
    const wallet = await this.ensureWallet(driverId);
    const before = Number(wallet.availableBalance);
    const after = direction === 'CREDIT' ? before + amount : before - amount;
    await this.prisma.driverWallet.update({
      where: { id: wallet.id },
      data: { availableBalance: after },
    });
    return this.prisma.walletTransaction.create({
      data: {
        walletId: wallet.id,
        transactionType: 'ADJUSTMENT',
        amount,
        direction,
        balanceBefore: before,
        balanceAfter: after,
        description,
      },
    });
  }

  private async ensureWallet(driverId: string) {
    return this.prisma.driverWallet.upsert({
      where: { driverId },
      create: { driverId },
      update: {},
    });
  }
}
