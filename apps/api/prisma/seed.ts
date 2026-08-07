import { PrismaClient, AdminRole, UserType } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding MaX Ride…');

  const categories = [
    {
      code: 'TUKTUK',
      name: 'Tuk Tuk',
      description: 'Economy three-wheeler',
      capacity: 3,
      sortOrder: 1,
      pricing: {
        name: 'Tuk Default LKR',
        baseFare: 150,
        perKmFare: 55,
        perMinuteFare: 3,
        bookingFee: 20,
        minimumFare: 200,
        waitingPerMinute: 2,
      },
    },
    {
      code: 'CAR',
      name: 'Car',
      description: 'Comfort sedan',
      capacity: 4,
      sortOrder: 2,
      pricing: {
        name: 'Car Default LKR',
        baseFare: 250,
        perKmFare: 85,
        perMinuteFare: 5,
        bookingFee: 40,
        minimumFare: 350,
        waitingPerMinute: 4,
      },
    },
    {
      code: 'VAN',
      name: 'Van',
      description: 'Family / group van',
      capacity: 7,
      sortOrder: 3,
      pricing: {
        name: 'Van Default LKR',
        baseFare: 400,
        perKmFare: 110,
        perMinuteFare: 7,
        bookingFee: 50,
        minimumFare: 550,
        waitingPerMinute: 5,
      },
    },
  ];

  for (const c of categories) {
    const cat = await prisma.vehicleCategory.upsert({
      where: { code: c.code },
      create: {
        code: c.code,
        name: c.name,
        description: c.description,
        capacity: c.capacity,
        sortOrder: c.sortOrder,
      },
      update: {
        name: c.name,
        description: c.description,
        capacity: c.capacity,
        sortOrder: c.sortOrder,
        isActive: true,
      },
    });

    const existing = await prisma.pricingRule.findFirst({
      where: { vehicleCategoryId: cat.id, isActive: true },
    });
    if (!existing) {
      await prisma.pricingRule.create({
        data: {
          vehicleCategoryId: cat.id,
          ...c.pricing,
          currency: 'LKR',
          surgeMultiplier: 1,
        },
      });
    }
  }

  await prisma.promoCode.upsert({
    where: { code: 'MAX10' },
    create: {
      code: 'MAX10',
      description: '10% off MaX Ride',
      discountType: 'PERCENT',
      discountValue: 10,
      maxDiscount: 300,
      minFare: 300,
      usageLimit: 10000,
      validFrom: new Date(),
      validTo: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
    },
    update: { isActive: true },
  });

  const adminPhone = '+94770000000';
  const passwordHash = await bcrypt.hash('admin123', 10);
  const admin = await prisma.user.upsert({
    where: { phoneNumber: adminPhone },
    create: {
      phoneNumber: adminPhone,
      fullName: 'MaX Super Admin',
      userType: UserType.ADMIN,
      phoneVerifiedAt: new Date(),
      passwordHash,
      adminProfile: { create: { role: AdminRole.SUPER_ADMIN } },
    },
    update: {
      passwordHash,
      fullName: 'MaX Super Admin',
      userType: UserType.ADMIN,
    },
  });

  // Ensure admin profile
  await prisma.adminProfile.upsert({
    where: { userId: admin.id },
    create: { userId: admin.id, role: AdminRole.SUPER_ADMIN },
    update: { role: AdminRole.SUPER_ADMIN },
  });

  console.log('Seed complete.');
  console.log('Admin login: phone +94770000000 / password admin123');
  console.log('OTP mock code: 123456');
  console.log('Promo: MAX10');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
