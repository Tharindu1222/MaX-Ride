# MaX Ride — Sri Lanka Ride-Hailing Platform

**Brand:** MaX Ride  
**Market:** Sri Lanka · **Currency:** LKR  
**Stack:** Flutter (passenger + driver) · Next.js admin · NestJS API · PostgreSQL · Redis

Full product blueprint: [`ride_hailing_app_full_development_blueprint.md`](./ride_hailing_app_full_development_blueprint.md)

---

## Monorepo layout

```text
max-ride/
├── apps/
│   ├── api/          # NestJS modular monolith
│   ├── admin/        # Next.js admin dashboard
│   ├── passenger/    # Flutter passenger app
│   └── driver/       # Flutter driver app
├── packages/shared/  # Shared TS types
├── docker-compose.yml
└── README.md
```

---

## Prerequisites

- Node.js 20+
- Flutter SDK
- Docker Desktop (Postgres + Redis)
- npm

---

## 1. Start infrastructure

```bash
# Start Docker Desktop first, then:
docker compose up -d
```

Services:

| Service  | Port |
|----------|------|
| Postgres | 5432 (`max_ride` / postgres / postgres) |
| Redis    | 6379 |

---

## 2. Backend API

```bash
cd apps/api
cp .env .env   # already seeded for local
npx prisma migrate dev --name init
npm run prisma:seed
npm run start:dev
```

- API: http://localhost:4000/api/v1  
- Health: http://localhost:4000/api/v1/health  
- Swagger: http://localhost:4000/docs  
- WebSocket: `http://localhost:4000/realtime`

### Mock services (local)

| Service   | Behaviour |
|-----------|-----------|
| OTP       | Always `123456` (logged to console) |
| Maps      | Fixture places (Colombo, Kandy, …) |
| Card pay  | Instant capture |
| Cash pay  | `CASH_COLLECTED` + wallet commission |
| FCM push  | Logged + stored as in-app notification |

### Seed credentials

| Role  | Login |
|-------|--------|
| Admin | Phone `+94770000000` / password `admin123` |
| Promo | `MAX10` (10% off) |
| OTP   | `123456` |

Vehicle categories: **Tuk Tuk**, **Car**, **Van** with LKR pricing rules.

---

## 3. Admin dashboard

```bash
cd apps/admin
# optional: set NEXT_PUBLIC_API_URL=http://localhost:4000/api/v1
npm run dev
```

Open http://localhost:3000 — sign in with seed admin.

Modules: dashboard, live rides, drivers (approve), passengers, pricing, promos, support, safety/SOS, audit, reports.

---

## 4. Flutter apps

```bash
# Passenger
cd apps/passenger
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1

# Driver
cd apps/driver
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

| Platform | API host for device |
|----------|---------------------|
| Android emulator | `http://10.0.2.2:4000/api/v1` |
| iOS simulator | `http://localhost:4000/api/v1` |
| Physical device | `http://<your-LAN-ip>:4000/api/v1` |

### Demo ride flow

1. Admin: login → approve drivers after they onboard.  
2. Driver app: OTP → Onboarding (docs + vehicle) → go Online (location updates).  
3. Passenger app: OTP → pick places → estimate → request ride (note **start PIN**).  
4. Driver receives offer (Socket event + DB `ride_driver_offers`; paste offer id on driver home for demo accept).  
5. Driver: Arrived → Start with PIN → Complete.  
6. Payment settles (cash/card mock); wallet updates; passenger rates.

---

## Core API map

| Area | Endpoints |
|------|-----------|
| Auth | `POST /auth/otp/request`, `/auth/otp/verify`, `/auth/admin/login`, `GET /auth/me` |
| Maps | `GET /maps/places`, `/maps/places/popular`, `/maps/geocode/reverse` |
| Pricing | `GET /vehicle-categories`, `POST /fares/estimate` |
| Rides | `POST /rides`, `GET /rides/:id`, offer accept/reject, arrived/start/complete/cancel/rate |
| Drivers | profile, documents, vehicles, online, location, earnings |
| Passengers | profile, saved places, history |
| Admin | dashboard, live rides, driver review, pricing, promos, wallets, audit, reports |
| Safety | `POST /safety/sos` |
| Support | tickets CRUD |

Standard envelope:

```json
{ "success": true, "data": { } }
```

---

## Root scripts

```bash
npm run docker:up
npm run dev:api
npm run dev:admin
npm run db:seed
```

---

## Out of scope (per blueprint)

Production hosting, DNS, multi-region, pooling, scheduled multi-stop, real SMS/FCM/payment gateway (interfaces ready to swap via env).

---

## License

Private — MaX Ride project.
