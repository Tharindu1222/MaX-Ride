-- AlterEnum
CREATE TYPE "ServiceType" AS ENUM ('RIDE', 'INTERCITY', 'RENTAL');

-- AlterEnum
CREATE TYPE "RentalPackageType" AS ENUM ('HOURLY', 'DAILY', 'FIXED_TRIP');

-- AlterTable pricing_rules
ALTER TABLE "pricing_rules" ADD COLUMN "service_type" "ServiceType" NOT NULL DEFAULT 'RIDE';

CREATE INDEX "pricing_rules_vehicle_category_id_service_type_is_active_idx" ON "pricing_rules"("vehicle_category_id", "service_type", "is_active");

-- CreateTable rental_packages
CREATE TABLE "rental_packages" (
    "id" UUID NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "description" TEXT,
    "package_type" "RentalPackageType" NOT NULL,
    "vehicle_category_id" UUID,
    "duration_hours" INTEGER,
    "included_km" INTEGER,
    "price" DECIMAL(12,2) NOT NULL,
    "currency" VARCHAR(10) NOT NULL DEFAULT 'LKR',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "rental_packages_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "rental_packages_is_active_sort_order_idx" ON "rental_packages"("is_active", "sort_order");

ALTER TABLE "rental_packages" ADD CONSTRAINT "rental_packages_vehicle_category_id_fkey" FOREIGN KEY ("vehicle_category_id") REFERENCES "vehicle_categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AlterTable rides
ALTER TABLE "rides" ADD COLUMN "service_type" "ServiceType" NOT NULL DEFAULT 'RIDE';
ALTER TABLE "rides" ADD COLUMN "rental_package_id" UUID;

ALTER TABLE "rides" ALTER COLUMN "dropoff_address" DROP NOT NULL;
ALTER TABLE "rides" ALTER COLUMN "dropoff_lat" DROP NOT NULL;
ALTER TABLE "rides" ALTER COLUMN "dropoff_lng" DROP NOT NULL;

CREATE INDEX "rides_service_type_idx" ON "rides"("service_type");

ALTER TABLE "rides" ADD CONSTRAINT "rides_rental_package_id_fkey" FOREIGN KEY ("rental_package_id") REFERENCES "rental_packages"("id") ON DELETE SET NULL ON UPDATE CASCADE;
