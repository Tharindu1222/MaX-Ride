# Service modes (Ride / Intercity / Rental) — Design

**Date:** 2026-09-04  
**Status:** Approved for implementation (Approach 1)

## Summary

After passenger login, show a service picker: **Ride**, **Intercity**, **Rental**. Then location booking. Admin manages rental packages and per-mode pricing. One `Ride` pipeline with `serviceType`; same driver pool by vehicle category.

## Passenger flow

1. OTP login → `/select` (Ride | Intercity | Rental)
2. Ride / Intercity → map pickup+dropoff → category → estimate → request
3. Rental → package list → locations (hourly/daily: pickup only; fixed: pickup+dropoff) → request
4. Dispatch via existing offers; history shows mode

## Data model

- `ServiceType`: `RIDE | INTERCITY | RENTAL`
- `RentalPackageType`: `HOURLY | DAILY | FIXED_TRIP`
- `PricingRule.serviceType` (default `RIDE`); fare lookup by category + serviceType
- `RentalPackage`: name, type, durationHours?, includedKm?, price, vehicleCategoryId?, isActive
- `Ride.serviceType`, `Ride.rentalPackageId?`; dropoff optional for hourly/daily rental

## Admin

- Packages CRUD page
- Pricing rules show/edit `serviceType` (city vs intercity)

## API

- `GET /rental-packages` (active)
- Admin: `GET/POST/PATCH /admin/packages`
- `POST /fares/estimate` + `POST /rides` accept `serviceType` + optional `rentalPackageId` + optional dropoff
