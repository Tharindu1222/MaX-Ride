# Ride-Hailing Mobile Application — Full Development Blueprint

> **Project type:** PickMe/Uber-style ride-hailing platform  
> **Scope:** Passenger App, Driver App, Admin Dashboard, Backend API, Real-time Location, Dispatch, Payments, Notifications, Security, Testing  
> **Excluded:** Hosting, production cloud infrastructure, server provisioning, DNS, deployment architecture  
> **Recommended stack:** Flutter, NestJS, TypeScript, PostgreSQL, PostGIS, Redis, Socket.IO, Firebase Cloud Messaging

---

## 1. Document Purpose

මෙම document එක ride-hailing platform එකක් beginning සිට development-ready level එකක් දක්වා design සහ implement කිරීමට අවශ්‍ය complete technical blueprint එකකි.

මෙය භාවිතා කළ හැක්කේ:

- Product requirements define කිරීමට
- UI/UX screens plan කිරීමට
- Database design කිරීමට
- Backend modules develop කිරීමට
- Passenger සහ Driver mobile applications develop කිරීමට
- Admin dashboard develop කිරීමට
- QA test cases සකස් කිරීමට
- Development team එකට tasks divide කිරීමට
- MVP scope control කිරීමට

මෙය PickMe හෝ Uber source code copy කිරීමක් නොවේ. Similar ride-booking workflow එකක් original branding, UI, pricing rules සහ business policies සමඟ develop කිරීමට භාවිතා කළ යුතුය.

---

# 2. Product Vision

Passenger කෙනෙකුට තමන්ගේ current location එකෙන් destination එකක් select කර ride එකක් request කිරීමට, nearby available driver කෙනෙකු system එකෙන් match කිරීමට, driver live location track කිරීමට, trip එක complete කිරීමට සහ cash/card payment process කිරීමට හැකි platform එකක් නිර්මාණය කිරීම.

Driver කෙනෙකුට:

- Register වීමට
- Documents upload කිරීමට
- Admin approval ලබාගැනීමට
- Online/Offline වීමට
- Ride requests accept/reject කිරීමට
- Passenger pickup කිරීමට
- Trip complete කිරීමට
- Earnings සහ wallet details බැලීමට

Admin users සඳහා:

- Drivers approve කිරීමට
- Passengers සහ rides manage කිරීමට
- Pricing configure කිරීමට
- Payments සහ driver settlements review කිරීමට
- Complaints සහ incidents handle කිරීමට
- Operational reports බැලීමට

---

# 3. Product Components

Platform එක ප්‍රධාන applications හතරකින් සමන්විත වේ.

## 3.1 Passenger Mobile App

Passenger booking සහ trip tracking සඳහා.

## 3.2 Driver Mobile App

Driver onboarding, availability, incoming ride offers, navigation, trip handling සහ earnings සඳහා.

## 3.3 Admin Web Dashboard

Operations, verification, finance, pricing, promotions, support, safety සහ reporting සඳහා.

## 3.4 Backend Platform

Authentication, ride management, dispatching, real-time communication, fare calculation, payments, notifications, audit logs සහ business rules සඳහා.

---

# 4. Recommended Technology Stack

| Layer | Technology |
|---|---|
| Passenger App | Flutter + Dart |
| Driver App | Flutter + Dart |
| State Management | Riverpod |
| Mobile Routing | GoRouter |
| Mobile Networking | Dio |
| Local Secure Storage | flutter_secure_storage |
| Maps | Google Maps Flutter |
| Background Location | geolocator + platform-specific background service |
| Admin Dashboard | Next.js + TypeScript |
| Admin UI | Tailwind CSS + shadcn/ui |
| Data Fetching | TanStack Query |
| Forms | React Hook Form + Zod |
| Backend | NestJS + TypeScript |
| ORM | Prisma or TypeORM |
| Main Database | PostgreSQL |
| Spatial Queries | PostGIS |
| Fast Location Store | Redis GEO |
| Background Jobs | BullMQ |
| Real-time Communication | Socket.IO |
| API Documentation | Swagger / OpenAPI |
| Push Notifications | Firebase Cloud Messaging |
| File Upload | S3-compatible/Azure Blob-compatible storage abstraction |
| Testing | Jest, Supertest, Flutter Test, Playwright |
| API Testing | Postman / Newman |
| Load Testing | k6 or JMeter |
| Code Quality | ESLint, Prettier, Husky, lint-staged |

## 4.1 ORM Recommendation

### Prisma

Use Prisma if:

- Team prefers strong TypeScript types
- Schema-first development is preferred
- Most queries are normal relational queries

### TypeORM

Use TypeORM if:

- Team already has NestJS + TypeORM experience
- Decorator-based entities are preferred
- More direct SQL/PostGIS control is required

**Recommended for this project:** TypeORM or Prisma with raw SQL support for advanced PostGIS queries.

---

# 5. Development Approach

## 5.1 Start as a Modular Monolith

First version එක microservices ලෙස build නොකරන්න.

Use one NestJS backend with clearly separated modules:

```text
src/
├── modules/
│   ├── auth/
│   ├── users/
│   ├── passengers/
│   ├── drivers/
│   ├── vehicles/
│   ├── documents/
│   ├── rides/
│   ├── dispatch/
│   ├── locations/
│   ├── pricing/
│   ├── payments/
│   ├── wallets/
│   ├── promotions/
│   ├── ratings/
│   ├── notifications/
│   ├── support/
│   ├── safety/
│   ├── admin/
│   └── audit/
├── common/
├── config/
├── database/
├── gateways/
├── jobs/
└── main.ts
```

Benefits:

- Faster MVP development
- Easier debugging
- Simpler transactions
- Lower operational complexity
- Clear future microservice split points

Future scaling සඳහා `dispatch`, `location`, `payments`, `notifications` වෙනම services බවට split කළ හැක.

---

# 6. MVP Scope

## 6.1 MVP Included Features

### Passenger

- Mobile number registration
- OTP login
- Profile management
- Current location detection
- Pickup location selection
- Destination search
- Fare estimate
- Vehicle category selection
- Cash/card payment selection
- Promo code application
- Ride request
- Driver matching
- Driver live location
- Driver details
- Call/chat action
- Ride cancellation
- Trip start PIN
- Live trip tracking
- Trip completion
- Receipt
- Driver rating
- Ride history
- Saved places
- Support ticket
- Trip sharing
- SOS

### Driver

- OTP login
- Driver registration
- Vehicle registration
- Document upload
- Admin approval
- Online/offline
- Location tracking
- Ride offer
- Accept/reject ride
- Navigate to passenger
- Arrived action
- Passenger start PIN verification
- Start trip
- Navigate to destination
- Complete trip
- Cash collection confirmation
- Earnings dashboard
- Wallet transactions
- Trip history
- Ratings
- Support
- Document expiry alerts

### Admin

- Login and RBAC
- Dashboard summary
- Live ride list
- Passenger management
- Driver verification
- Vehicle verification
- Document approval
- Driver suspension
- Ride management
- Pricing configuration
- Vehicle category management
- Promo code management
- Payment management
- Driver wallet adjustment
- Refund requests
- Support tickets
- Safety incidents
- Audit logs
- Reports

## 6.2 Features Excluded from MVP

- Ride pooling
- Corporate accounts
- Subscription plans
- Scheduled rides
- Multiple destination stops
- Driver bidding
- Food delivery
- Parcel delivery
- Loyalty points
- AI demand forecasting
- Advanced surge prediction
- In-app VoIP calls
- Multi-country support
- Cryptocurrency payments

---

# 7. User Roles

## 7.1 Passenger

Can:

- Manage own profile
- Search locations
- Estimate fare
- Request and cancel rides
- Track assigned driver
- View own ride history
- Rate driver
- Raise support tickets

Cannot:

- Access other passenger data
- Change fare
- Assign drivers
- Change completed ride status

## 7.2 Driver

Can:

- Manage own profile and documents
- Manage own vehicle details
- Go online/offline
- Receive ride offers
- Accept/reject offers
- Change ride state according to valid workflow
- View own earnings and history

Cannot:

- Manually assign a passenger
- Change pricing
- Complete a ride before it starts
- Access another driver’s earnings

## 7.3 Operations Admin

Can:

- View active rides
- View passengers and drivers
- Handle ride issues
- Cancel rides with reason
- Manage support issues

## 7.4 Verification Officer

Can:

- Review driver documents
- Approve/reject drivers
- Approve/reject vehicles
- Add verification notes

## 7.5 Finance Admin

Can:

- View payments
- Process approved refunds
- Review driver balances
- Approve payouts
- Export finance reports

## 7.6 Marketing Admin

Can:

- Manage promotions
- Manage campaign notifications
- View promotion performance

## 7.7 Super Admin

Has full platform permissions.

---

# 8. Main Business Workflows

## 8.1 Passenger Registration

```mermaid
sequenceDiagram
    participant P as Passenger App
    participant API as Backend API
    participant OTP as OTP Provider
    participant DB as Database

    P->>API: Request OTP with phone number
    API->>API: Validate and rate limit
    API->>DB: Save OTP request
    API->>OTP: Send OTP
    OTP-->>P: SMS OTP
    P->>API: Submit OTP
    API->>DB: Verify OTP record
    API->>DB: Create or fetch user
    API-->>P: Access token + refresh token
```

## 8.2 Driver Onboarding

```mermaid
flowchart TD
    A[Create Driver Account] --> B[Enter Personal Details]
    B --> C[Register Vehicle]
    C --> D[Upload Documents]
    D --> E[Submit Application]
    E --> F[Admin Review]
    F -->|Approved| G[Driver Active]
    F -->|Rejected| H[Correction Required]
    H --> D
```

## 8.3 Ride Booking

```mermaid
sequenceDiagram
    participant P as Passenger
    participant API as Ride API
    participant Pricing as Pricing Engine
    participant Dispatch as Dispatch Engine
    participant D as Driver
    participant WS as WebSocket Gateway

    P->>API: Request fare estimate
    API->>Pricing: Calculate estimate
    Pricing-->>P: Vehicle options and fares

    P->>API: Create ride request
    API->>Dispatch: Find eligible drivers
    Dispatch->>D: Send ride offer
    D->>API: Accept ride
    API->>API: Atomically assign driver
    API->>WS: Emit driver assigned
    WS-->>P: Driver assigned event
```

## 8.4 Trip Completion

```mermaid
flowchart TD
    A[Driver Arrives] --> B[Passenger Gives Start PIN]
    B --> C[Driver Verifies PIN]
    C --> D[Start Trip]
    D --> E[Live Location Tracking]
    E --> F[Reach Destination]
    F --> G[Complete Trip]
    G --> H[Calculate Final Fare]
    H --> I{Payment Type}
    I -->|Cash| J[Confirm Cash Collected]
    I -->|Card| K[Process Card Payment]
    J --> L[Credit Driver Wallet]
    K --> L
    L --> M[Generate Receipt]
    M --> N[Passenger Rating]
```

---

# 9. Ride State Machine

## 9.1 Ride Statuses

```text
DRAFT
FARE_ESTIMATED
SEARCHING_DRIVER
DRIVER_ASSIGNED
DRIVER_EN_ROUTE
DRIVER_ARRIVED
TRIP_STARTED
TRIP_COMPLETED
PAYMENT_PENDING
PAYMENT_COMPLETED
PASSENGER_CANCELLED
DRIVER_CANCELLED
ADMIN_CANCELLED
NO_DRIVER_AVAILABLE
PAYMENT_FAILED
DISPUTED
```

## 9.2 Valid Transitions

| Current State | Allowed Next States |
|---|---|
| DRAFT | FARE_ESTIMATED |
| FARE_ESTIMATED | SEARCHING_DRIVER |
| SEARCHING_DRIVER | DRIVER_ASSIGNED, PASSENGER_CANCELLED, NO_DRIVER_AVAILABLE |
| DRIVER_ASSIGNED | DRIVER_EN_ROUTE, DRIVER_CANCELLED, PASSENGER_CANCELLED |
| DRIVER_EN_ROUTE | DRIVER_ARRIVED, DRIVER_CANCELLED, PASSENGER_CANCELLED |
| DRIVER_ARRIVED | TRIP_STARTED, DRIVER_CANCELLED, PASSENGER_CANCELLED |
| TRIP_STARTED | TRIP_COMPLETED, ADMIN_CANCELLED |
| TRIP_COMPLETED | PAYMENT_PENDING, PAYMENT_COMPLETED |
| PAYMENT_PENDING | PAYMENT_COMPLETED, PAYMENT_FAILED |
| PAYMENT_FAILED | PAYMENT_PENDING, DISPUTED |

## 9.3 State Enforcement Rules

- Backend must validate every transition.
- Mobile clients must not directly set arbitrary statuses.
- Every status change must create a history record.
- Status changes should include actor, timestamp, coordinates, reason and metadata.
- Critical state transitions must use database transactions.
- `TRIP_STARTED` requires valid start PIN.
- `TRIP_COMPLETED` requires an active started trip.
- Driver assignment must be atomic.

---

# 10. Driver Status Model

```text
OFFLINE
ONLINE_AVAILABLE
OFFER_RECEIVED
GOING_TO_PICKUP
ARRIVED_AT_PICKUP
ON_TRIP
BREAK
SUSPENDED
DOCUMENTS_EXPIRED
```

## Rules

- Driver with expired mandatory documents cannot go online.
- Driver can have only one active ride.
- Driver cannot receive offers while `ON_TRIP`.
- Driver app must send heartbeat while online.
- Driver becomes temporarily unavailable if heartbeat stops.
- Admin suspension immediately removes the driver from dispatch eligibility.

---

# 11. Database Design

## 11.1 General Rules

- Use UUID primary keys.
- Add `created_at` and `updated_at` to all main tables.
- Use soft delete only where business history must remain.
- Store money as integer minor units or decimal with fixed precision.
- Never use floating-point types for monetary values.
- Store time in UTC.
- Store location as PostGIS geography points.
- Add database constraints for important business invariants.
- Add indexes for search and dispatch fields.

---

## 11.2 Core Entity Relationship Diagram

```mermaid
erDiagram
    USERS ||--o| PASSENGER_PROFILES : has
    USERS ||--o| DRIVER_PROFILES : has
    DRIVER_PROFILES ||--o{ DRIVER_DOCUMENTS : uploads
    DRIVER_PROFILES ||--o{ VEHICLE_DRIVER_ASSIGNMENTS : assigned
    VEHICLES ||--o{ VEHICLE_DRIVER_ASSIGNMENTS : has
    VEHICLE_CATEGORIES ||--o{ VEHICLES : classifies
    PASSENGER_PROFILES ||--o{ RIDES : requests
    DRIVER_PROFILES ||--o{ RIDES : completes
    RIDES ||--o{ RIDE_STATUS_HISTORY : tracks
    RIDES ||--o{ RIDE_DRIVER_OFFERS : offered
    RIDES ||--o{ PAYMENTS : has
    RIDES ||--o{ RATINGS : receives
    DRIVER_PROFILES ||--|| DRIVER_WALLETS : owns
    DRIVER_WALLETS ||--o{ WALLET_TRANSACTIONS : contains
    USERS ||--o{ USER_DEVICES : registers
    USERS ||--o{ SUPPORT_TICKETS : creates
```

---

## 11.3 Users Table

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255),
    full_name VARCHAR(150),
    profile_image_url TEXT,
    user_type VARCHAR(30) NOT NULL,
    account_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    phone_verified_at TIMESTAMPTZ,
    email_verified_at TIMESTAMPTZ,
    preferred_language VARCHAR(10) DEFAULT 'en',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## 11.4 Driver Profiles

```sql
CREATE TABLE driver_profiles (
    id UUID PRIMARY KEY,
    user_id UUID UNIQUE NOT NULL REFERENCES users(id),
    nic_number VARCHAR(30),
    driving_license_number VARCHAR(50),
    date_of_birth DATE,
    approval_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    operational_status VARCHAR(30) NOT NULL DEFAULT 'OFFLINE',
    average_rating NUMERIC(3,2) DEFAULT 0,
    total_completed_rides INTEGER DEFAULT 0,
    acceptance_rate NUMERIC(5,2) DEFAULT 0,
    cancellation_rate NUMERIC(5,2) DEFAULT 0,
    approved_at TIMESTAMPTZ,
    approved_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## 11.5 Vehicles

```sql
CREATE TABLE vehicles (
    id UUID PRIMARY KEY,
    vehicle_category_id UUID NOT NULL,
    registration_number VARCHAR(30) UNIQUE NOT NULL,
    make VARCHAR(80),
    model VARCHAR(80),
    manufacture_year INTEGER,
    color VARCHAR(50),
    approval_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## 11.6 Rides

```sql
CREATE TABLE rides (
    id UUID PRIMARY KEY,
    ride_number VARCHAR(40) UNIQUE NOT NULL,
    passenger_id UUID NOT NULL,
    driver_id UUID,
    vehicle_id UUID,
    vehicle_category_id UUID NOT NULL,

    pickup_address TEXT NOT NULL,
    pickup_location GEOGRAPHY(POINT, 4326) NOT NULL,
    dropoff_address TEXT NOT NULL,
    dropoff_location GEOGRAPHY(POINT, 4326) NOT NULL,

    status VARCHAR(40) NOT NULL,
    payment_method VARCHAR(30) NOT NULL,

    estimated_distance_meters INTEGER,
    estimated_duration_seconds INTEGER,
    estimated_fare NUMERIC(12,2),

    actual_distance_meters INTEGER,
    actual_duration_seconds INTEGER,
    final_fare NUMERIC(12,2),

    discount_amount NUMERIC(12,2) DEFAULT 0,
    booking_fee NUMERIC(12,2) DEFAULT 0,
    waiting_fee NUMERIC(12,2) DEFAULT 0,
    surge_multiplier NUMERIC(6,2) DEFAULT 1,

    passenger_note TEXT,
    start_pin_hash TEXT,

    requested_at TIMESTAMPTZ,
    driver_assigned_at TIMESTAMPTZ,
    driver_arrived_at TIMESTAMPTZ,
    trip_started_at TIMESTAMPTZ,
    trip_completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## 11.7 Ride Status History

```sql
CREATE TABLE ride_status_history (
    id UUID PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES rides(id),
    previous_status VARCHAR(40),
    new_status VARCHAR(40) NOT NULL,
    changed_by_user_id UUID,
    actor_type VARCHAR(30),
    reason_code VARCHAR(50),
    notes TEXT,
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## 11.8 Driver Offers

```sql
CREATE TABLE ride_driver_offers (
    id UUID PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES rides(id),
    driver_id UUID NOT NULL REFERENCES driver_profiles(id),
    offer_status VARCHAR(30) NOT NULL,
    offered_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    responded_at TIMESTAMPTZ,
    pickup_distance_meters INTEGER,
    pickup_eta_seconds INTEGER,
    ranking_score NUMERIC(12,4)
);
```

## 11.9 Payments

```sql
CREATE TABLE payments (
    id UUID PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES rides(id),
    passenger_id UUID NOT NULL,
    payment_method VARCHAR(30) NOT NULL,
    gateway VARCHAR(50),
    gateway_reference VARCHAR(150),
    amount NUMERIC(12,2) NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'LKR',
    status VARCHAR(30) NOT NULL,
    idempotency_key VARCHAR(100),
    failure_code VARCHAR(100),
    failure_message TEXT,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## 11.10 Driver Wallet

```sql
CREATE TABLE driver_wallets (
    id UUID PRIMARY KEY,
    driver_id UUID UNIQUE NOT NULL,
    available_balance NUMERIC(12,2) NOT NULL DEFAULT 0,
    pending_balance NUMERIC(12,2) NOT NULL DEFAULT 0,
    cash_balance NUMERIC(12,2) NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

```sql
CREATE TABLE wallet_transactions (
    id UUID PRIMARY KEY,
    wallet_id UUID NOT NULL REFERENCES driver_wallets(id),
    ride_id UUID,
    transaction_type VARCHAR(40) NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    direction VARCHAR(10) NOT NULL,
    balance_before NUMERIC(12,2) NOT NULL,
    balance_after NUMERIC(12,2) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

# 12. Important Database Indexes

```sql
CREATE INDEX idx_rides_passenger_created
ON rides(passenger_id, created_at DESC);

CREATE INDEX idx_rides_driver_created
ON rides(driver_id, created_at DESC);

CREATE INDEX idx_rides_status
ON rides(status);

CREATE INDEX idx_rides_pickup_location
ON rides USING GIST(pickup_location);

CREATE INDEX idx_rides_dropoff_location
ON rides USING GIST(dropoff_location);

CREATE INDEX idx_driver_offers_driver_status
ON ride_driver_offers(driver_id, offer_status);

CREATE INDEX idx_ride_status_history_ride
ON ride_status_history(ride_id, created_at);
```

---

# 13. Location Architecture

## 13.1 Current Driver Location

Current online driver location should be stored in Redis GEO.

Example conceptual keys:

```text
geo:drivers:bike
geo:drivers:tuk
geo:drivers:car
geo:drivers:van
```

Driver metadata:

```text
driver:online:{driverId}
driver:heartbeat:{driverId}
driver:activeRide:{driverId}
```

## 13.2 Driver Location Update Flow

```mermaid
sequenceDiagram
    participant D as Driver App
    participant WS as WebSocket Gateway
    participant Redis as Redis
    participant P as Passenger App
    participant DB as PostgreSQL

    D->>WS: location.update
    WS->>WS: Authenticate driver
    WS->>Redis: Update GEO location
    WS->>Redis: Update heartbeat
    alt Driver has active ride
        WS-->>P: ride.driver_location_updated
        WS->>DB: Queue selected route point
    end
```

## 13.3 Location Update Frequency

| State | Recommended Frequency |
|---|---:|
| Offline | No updates |
| Online and idle | 8–15 seconds |
| Going to pickup | 3–5 seconds |
| On trip | 2–5 seconds |
| App background with active trip | 5–10 seconds |

Use adaptive tracking to reduce battery usage.

## 13.4 Location Validation

Backend should reject or flag:

- Invalid latitude/longitude
- Impossible speed
- Very old timestamps
- Duplicate updates
- Large location jumps
- Mocked/fake GPS indicators
- Driver location outside allowed service area

---

# 14. Dispatch and Driver Matching

## 14.1 Eligibility Filters

A driver is eligible only if:

- Account is approved
- Account is not suspended
- Mandatory documents are valid
- Vehicle is approved
- Vehicle category matches
- Driver is online and available
- Driver has recent heartbeat
- Driver has no active ride
- Driver is inside service area
- Driver is within search radius

## 14.2 Search Rounds

```text
Round 1: 1.5 km
Round 2: 3 km
Round 3: 5 km
Round 4: 8 km
```

Each round can use a configurable offer timeout.

Example:

```text
Offer timeout: 15 seconds
Maximum simultaneous offers: 3
Maximum total search time: 90 seconds
```

## 14.3 Ranking Formula

```text
ranking_score =
    pickup_eta_score
  + idle_time_score
  + acceptance_reliability_score
  + cancellation_score
  + rating_score
```

Recommended MVP priority:

1. Lowest pickup ETA
2. Longest idle time
3. Lower recent cancellation rate
4. Higher rating

## 14.4 Atomic Driver Assignment

Two drivers may accept at nearly the same time.

Use a database transaction or atomic lock:

```text
1. Lock ride row.
2. Confirm status is SEARCHING_DRIVER.
3. Confirm driver is still available.
4. Set assigned driver.
5. Set ride status DRIVER_ASSIGNED.
6. Mark accepted offer.
7. Expire all other offers.
8. Commit transaction.
```

Only the first valid acceptance succeeds.

## 14.5 No Driver Available

If no driver accepts:

- Set status `NO_DRIVER_AVAILABLE`
- Notify passenger
- Release reserved payment authorization if any
- Allow passenger to retry
- Store matching metrics

---

# 15. Fare Calculation Engine

## 15.1 Basic Formula

```text
Fare =
Base Fare
+ Distance Charge
+ Time Charge
+ Waiting Charge
+ Booking Fee
+ Zone Adjustment
+ Peak Adjustment
- Promotion Discount
```

## 15.2 Example

```text
Base Fare:                         Rs. 100
Distance: 8 km × Rs. 80:          Rs. 640
Time: 20 minutes × Rs. 5:         Rs. 100
Booking Fee:                       Rs. 30
Subtotal:                          Rs. 870
Promotion Discount:               Rs. 100
Final Fare:                        Rs. 770
```

## 15.3 Pricing Rule Table

Suggested fields:

```text
id
vehicle_category_id
service_zone_id
base_fare
minimum_fare
price_per_km
price_per_minute
waiting_price_per_minute
booking_fee
cancellation_fee
surge_multiplier
effective_from
effective_to
is_active
```

## 15.4 Fare Estimate vs Final Fare

Always store both:

```text
estimated_distance
estimated_duration
estimated_fare

actual_distance
actual_duration
actual_fare
```

## 15.5 Fare Calculation Rules

- Backend is the source of truth.
- Mobile app must never calculate authoritative fare.
- Every fare should have a breakdown.
- Pricing version used for a ride must be saved.
- Promotion must be validated again at booking.
- Final fare should be calculated once, using idempotency protection.
- Admin fare adjustment requires reason and audit log.

---

# 16. Cancellation Rules

## 16.1 Passenger Cancellation

Possible reasons:

- Driver is too far
- Driver not moving
- Change of plan
- Wrong pickup location
- Booked by mistake
- Driver requested cancellation
- Other

## 16.2 Driver Cancellation

Possible reasons:

- Passenger unreachable
- Unsafe pickup location
- Vehicle issue
- Passenger no-show
- Incorrect passenger details
- Emergency
- Other

## 16.3 Cancellation Fee

Configurable rules:

- No fee before driver assignment
- No fee within grace period
- Fee after driver travels toward pickup
- No-show fee after driver waits configured time
- Waive fee for driver fault or system failure

All cancellation fee decisions must be explainable and stored.

---

# 17. Payment Design

## 17.1 Supported MVP Payment Types

```text
CASH
CARD
PROMO_CREDIT
DRIVER_WALLET_ADJUSTMENT
```

## 17.2 Card Payment Flow

```mermaid
sequenceDiagram
    participant P as Passenger App
    participant API as Backend
    participant PG as Payment Gateway
    participant DB as Database

    P->>API: Select saved card
    API->>PG: Create/verify payment method
    P->>API: Request ride
    API->>DB: Save selected payment method
    API->>PG: Optional preauthorization
    API-->>P: Ride confirmed

    Note over API,PG: After trip completion
    API->>API: Calculate final fare
    API->>PG: Charge token
    PG-->>API: Payment callback/webhook
    API->>API: Verify signature
    API->>DB: Update payment idempotently
    API-->>P: Payment completed
```

## 17.3 Payment Rules

- Never store raw card numbers.
- Store gateway token only.
- Verify all callbacks/webhooks.
- Use idempotency keys.
- Keep payment status separate from ride status.
- Store every payment attempt.
- Do not trust payment success response from mobile app.
- Refund must be linked to original payment.
- Finance actions require audit logs.

## 17.4 Payment Statuses

```text
PENDING
AUTHORIZED
PROCESSING
COMPLETED
FAILED
CANCELLED
PARTIALLY_REFUNDED
REFUNDED
```

## 17.5 Cash Ride Accounting

For cash rides:

- Passenger pays driver directly.
- Platform commission becomes driver wallet liability.
- Wallet transaction records commission debit.
- Driver may need to settle negative cash balance.

---

# 18. Driver Wallet Rules

Wallet transaction types:

```text
RIDE_EARNING
PLATFORM_COMMISSION
CASH_RIDE_COMMISSION
PROMOTION_BONUS
INCENTIVE
PENALTY
REFUND_ADJUSTMENT
MANUAL_CREDIT
MANUAL_DEBIT
PAYOUT
```

Every transaction must include:

- Transaction type
- Amount
- Direction
- Balance before
- Balance after
- Ride reference if applicable
- Admin reference if manual
- Reason
- Timestamp

Never update wallet balance without creating a transaction record.

---

# 19. Authentication and Session Management

## 19.1 OTP Authentication

Endpoints:

```http
POST /api/v1/auth/request-otp
POST /api/v1/auth/verify-otp
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
POST /api/v1/auth/logout-all
```

## 19.2 OTP Security

- OTP expiry: 2–5 minutes
- Maximum attempts per OTP
- Request cooldown
- Phone-based rate limit
- IP-based rate limit
- Device-based rate limit
- Hash OTP before storing
- Mark OTP as consumed
- Do not log OTP values

## 19.3 Token Strategy

- Short-lived access token
- Long-lived refresh token
- Refresh token rotation
- Store refresh token hash
- Revoke old token after rotation
- Store device session
- Support logout from all devices

## 19.4 Access Token Claims

```json
{
  "sub": "user-id",
  "role": "DRIVER",
  "sessionId": "session-id",
  "permissions": ["ride:accept", "ride:start"]
}
```

---

# 20. Role-Based Access Control

Permission examples:

```text
driver:view
driver:approve
driver:suspend
vehicle:approve
ride:view
ride:cancel
ride:adjust_fare
payment:view
payment:refund
wallet:adjust
promotion:create
promotion:update
support:manage
incident:manage
audit:view
```

Use guards in NestJS:

```typescript
@UseGuards(JwtAuthGuard, PermissionsGuard)
@RequirePermissions('driver:approve')
@Post(':driverId/approve')
approveDriver() {}
```

---

# 21. REST API Design

Base URL:

```text
/api/v1
```

## 21.1 Authentication

```http
POST /auth/request-otp
POST /auth/verify-otp
POST /auth/refresh
POST /auth/logout
POST /auth/logout-all
```

## 21.2 Passenger Profile

```http
GET    /passengers/me
PATCH  /passengers/me
POST   /passengers/me/profile-image
GET    /passengers/me/saved-places
POST   /passengers/me/saved-places
PATCH  /passengers/me/saved-places/:id
DELETE /passengers/me/saved-places/:id
```

## 21.3 Driver Profile

```http
GET   /drivers/me
PATCH /drivers/me
POST  /drivers/me/documents
GET   /drivers/me/documents
POST  /drivers/me/vehicle
PATCH /drivers/me/vehicle
POST  /drivers/me/submit-application
POST  /drivers/me/status
GET   /drivers/me/earnings
GET   /drivers/me/wallet
GET   /drivers/me/rides
```

## 21.4 Fare Estimate

```http
POST /rides/estimate
```

Request:

```json
{
  "pickup": {
    "latitude": 6.9271,
    "longitude": 79.8612,
    "address": "Colombo"
  },
  "dropoff": {
    "latitude": 6.9147,
    "longitude": 79.9729,
    "address": "Battaramulla"
  },
  "promoCode": "WELCOME100"
}
```

Response:

```json
{
  "estimateId": "uuid",
  "expiresAt": "2026-08-07T05:10:00Z",
  "vehicleOptions": [
    {
      "categoryId": "uuid",
      "name": "Tuk",
      "estimatedPickupMinutes": 4,
      "estimatedDistanceMeters": 10500,
      "estimatedDurationSeconds": 1800,
      "estimatedFare": 1250,
      "currency": "LKR"
    }
  ]
}
```

## 21.5 Ride Management

```http
POST /rides
GET  /rides/:rideId
GET  /rides
POST /rides/:rideId/cancel
POST /rides/:rideId/rating
POST /rides/:rideId/share-token
```

## 21.6 Driver Ride Actions

```http
GET  /driver/ride-offers
POST /driver/rides/:rideId/accept
POST /driver/rides/:rideId/reject
POST /driver/rides/:rideId/arrived
POST /driver/rides/:rideId/start
POST /driver/rides/:rideId/complete
POST /driver/rides/:rideId/cancel
```

## 21.7 Payments

```http
GET  /payment-methods
POST /payment-methods
DELETE /payment-methods/:id

POST /payments/authorize
POST /payments/charge
POST /payments/webhooks/:gateway
POST /payments/:paymentId/refund
```

## 21.8 Support and Safety

```http
POST /support/tickets
GET  /support/tickets
GET  /support/tickets/:id
POST /support/tickets/:id/messages

POST /rides/:rideId/sos
POST /rides/:rideId/report
```

## 21.9 Admin APIs

```http
GET   /admin/dashboard
GET   /admin/drivers
GET   /admin/drivers/:id
POST  /admin/drivers/:id/approve
POST  /admin/drivers/:id/reject
POST  /admin/drivers/:id/suspend

GET   /admin/rides
GET   /admin/rides/:id
POST  /admin/rides/:id/cancel
POST  /admin/rides/:id/fare-adjustment

GET   /admin/payments
POST  /admin/payments/:id/refund

GET   /admin/pricing-rules
POST  /admin/pricing-rules
PATCH /admin/pricing-rules/:id

GET   /admin/promotions
POST  /admin/promotions
PATCH /admin/promotions/:id

GET   /admin/support-tickets
PATCH /admin/support-tickets/:id

GET   /admin/audit-logs
```

---

# 22. Standard API Response Format

Success:

```json
{
  "success": true,
  "data": {},
  "meta": {
    "requestId": "req-uuid"
  }
}
```

Error:

```json
{
  "success": false,
  "error": {
    "code": "RIDE_INVALID_STATE",
    "message": "Ride cannot be started from the current state",
    "details": {}
  },
  "meta": {
    "requestId": "req-uuid"
  }
}
```

---

# 23. Idempotency

Critical endpoints requiring idempotency:

- Create ride
- Accept ride
- Start trip
- Complete trip
- Charge payment
- Process payment webhook
- Refund payment
- Credit/debit wallet

Client sends:

```http
Idempotency-Key: unique-request-uuid
```

Backend stores:

```text
key
user_id
endpoint
request_hash
response_status
response_body
expires_at
```

---

# 24. WebSocket Design

## 24.1 Connection

Namespaces:

```text
/passenger
/driver
/admin
```

Authentication:

```text
Socket handshake with access token
```

## 24.2 Rooms

```text
user:{userId}
driver:{driverId}
ride:{rideId}
admin:operations
```

## 24.3 Passenger Events

```text
ride.searching
ride.driver_assigned
ride.driver_en_route
ride.driver_location_updated
ride.driver_arrived
ride.started
ride.completed
ride.cancelled
ride.no_driver_available
payment.completed
payment.failed
support.updated
```

## 24.4 Driver Events

```text
driver.ride_offer
driver.offer_expired
driver.offer_cancelled
driver.ride_assigned
driver.passenger_cancelled
driver.payment_confirmed
driver.account_suspended
driver.document_expiring
```

## 24.5 Client-to-Server Events

```text
driver.location.update
driver.heartbeat
ride.join
ride.leave
chat.message.send
```

## 24.6 Security

- Authenticate every socket.
- Authorize room joins.
- Validate payloads.
- Rate limit location updates.
- Do not expose passenger phone number unnecessarily.
- Disconnect suspended users.
- Log critical socket events.

---

# 25. Passenger App Screens

## 25.1 Authentication

1. Splash Screen
2. Language Selection
3. Welcome Screen
4. Phone Number Screen
5. OTP Verification
6. Name/Profile Setup
7. Permission Request Screens

## 25.2 Home and Booking

1. Home Map
2. Pickup Selection
3. Destination Search
4. Map Pin Adjustment
5. Recent Places
6. Saved Places
7. Fare Options
8. Payment Method
9. Promo Code
10. Booking Confirmation
11. Searching Driver

## 25.3 Active Ride

1. Driver Assigned
2. Driver Approaching
3. Driver Arrived
4. Start PIN
5. Trip in Progress
6. Share Trip
7. SOS
8. Change Destination Request
9. Ride Completed
10. Payment Result
11. Rating

## 25.4 Other Passenger Screens

1. Ride History
2. Ride Details
3. Receipts
4. Saved Locations
5. Payment Methods
6. Promotions
7. Support
8. Emergency Contacts
9. Notifications
10. Profile
11. Privacy and Terms
12. Delete Account

---

# 26. Driver App Screens

## 26.1 Onboarding

1. Splash
2. Phone Login
3. OTP
4. Personal Details
5. NIC Details
6. Driving Licence Details
7. Vehicle Details
8. Document Upload
9. Bank Details
10. Application Review
11. Pending Approval
12. Correction Required
13. Approved

## 26.2 Main Operations

1. Driver Home Map
2. Online/Offline Toggle
3. Incoming Ride Offer
4. Pickup Navigation
5. Passenger Details
6. Arrived Screen
7. Start PIN Verification
8. Trip Navigation
9. Trip Completion
10. Cash Collection
11. Payment Confirmation

## 26.3 Driver Management

1. Earnings
2. Wallet
3. Wallet Transactions
4. Trip History
5. Incentives
6. Ratings
7. Documents
8. Vehicle
9. Support
10. Notifications
11. Settings
12. Logout

---

# 27. Flutter App Architecture

Repository:

```text
mobile/
├── apps/
│   ├── passenger_app/
│   └── driver_app/
├── packages/
│   ├── design_system/
│   ├── api_client/
│   ├── auth/
│   ├── maps/
│   ├── location/
│   ├── notifications/
│   ├── models/
│   └── utilities/
└── melos.yaml
```

Passenger app:

```text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme.dart
├── core/
│   ├── config/
│   ├── errors/
│   ├── network/
│   ├── storage/
│   └── widgets/
├── features/
│   ├── auth/
│   ├── home/
│   ├── places/
│   ├── fare_estimate/
│   ├── booking/
│   ├── active_ride/
│   ├── payments/
│   ├── history/
│   ├── ratings/
│   ├── support/
│   └── profile/
└── main.dart
```

Feature structure:

```text
features/booking/
├── data/
│   ├── booking_api.dart
│   ├── booking_repository_impl.dart
│   └── models/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── controllers/
    ├── screens/
    └── widgets/
```

## 27.1 Recommended Mobile Patterns

- Repository pattern
- Feature-first folder structure
- Riverpod state management
- Immutable models
- Central API error mapping
- Secure token storage
- Environment configuration
- Offline-safe state restoration for active rides
- Deep-link support
- Push notification routing

---

# 28. Passenger App State Example

```dart
sealed class ActiveRideState {}

class NoActiveRide extends ActiveRideState {}

class SearchingDriver extends ActiveRideState {
  final String rideId;
  SearchingDriver(this.rideId);
}

class DriverAssigned extends ActiveRideState {
  final Ride ride;
  DriverAssigned(this.ride);
}

class TripInProgress extends ActiveRideState {
  final Ride ride;
  TripInProgress(this.ride);
}

class RideCompleted extends ActiveRideState {
  final Ride ride;
  RideCompleted(this.ride);
}
```

App startup එකේ:

1. Load secure session.
2. Fetch `/passengers/me`.
3. Fetch current active ride.
4. Reconnect socket.
5. Join ride room.
6. Restore correct screen.

---

# 29. Driver Background Location Requirements

Driver app requires reliable background location during:

- Online availability
- Going to pickup
- Active trip

Rules:

- Explain why location is required.
- Ask permission at the correct moment.
- Stop tracking when driver goes offline.
- Use foreground service on Android where required.
- Show persistent notification during active tracking.
- Handle app killed/restarted.
- Retry unsent important location points.
- Do not continuously store all idle GPS points permanently.

---

# 30. Admin Dashboard Modules

## 30.1 Dashboard

Cards:

- Online drivers
- Available drivers
- Active rides
- Searching rides
- Completed rides today
- Cancelled rides today
- Gross booking value
- Payment failures
- Open support tickets
- Open safety incidents

## 30.2 Live Operations

- Live active ride table
- Driver status
- Passenger status
- Ride timeline
- Current coordinates
- Estimated delays
- Cancel ride action
- Contact action
- Incident escalation

## 30.3 Driver Verification

- Pending applications
- Driver profile
- Vehicle profile
- Document preview
- Expiry dates
- Approve
- Reject
- Request correction
- Verification notes
- Verification history

## 30.4 Pricing

- Vehicle categories
- Base fares
- Per-km rates
- Per-minute rates
- Minimum fares
- Booking fees
- Waiting charges
- Cancellation charges
- Service zones
- Effective dates

## 30.5 Promotions

- Promo code
- Promotion type
- Discount amount
- Maximum discount
- Minimum ride amount
- Start/end date
- Usage limit
- User usage limit
- Applicable categories
- Applicable zones
- Active status

## 30.6 Finance

- Payment list
- Payment details
- Failed payments
- Refund requests
- Driver wallet balances
- Payout requests
- Manual adjustments
- Settlement reports

## 30.7 Support and Safety

- Ticket queue
- Ticket priority
- Assigned agent
- Ride context
- Internal notes
- Customer messages
- Incident severity
- Evidence uploads
- Resolution
- Escalation history

## 30.8 Audit Logs

Show:

- Actor
- Action
- Resource type
- Resource ID
- Previous value
- New value
- IP
- User agent
- Date/time

---

# 31. Notification System

## 31.1 Channels

- Push notification
- SMS
- Email
- In-app notification

## 31.2 Passenger Notifications

- OTP
- Driver assigned
- Driver arrived
- Ride cancelled
- Trip completed
- Payment completed
- Payment failed
- Refund completed
- Support response
- Promotional message

## 31.3 Driver Notifications

- OTP
- New ride offer
- Passenger cancelled
- Payment confirmed
- Document expiry
- Approval result
- Wallet adjustment
- Incentive achieved
- Support response

## 31.4 Notification Table

```text
id
user_id
type
title
body
data_json
channel
status
sent_at
read_at
created_at
```

## 31.5 Background Jobs

Use BullMQ queues:

```text
notifications
payments
driver-document-expiry
ride-timeouts
offer-expiry
receipts
wallet-processing
reports
```

---

# 32. Support and Incident Management

## 32.1 Ticket Categories

```text
PAYMENT
DRIVER_BEHAVIOUR
PASSENGER_BEHAVIOUR
LOST_ITEM
FARE_DISPUTE
CANCELLATION
SAFETY
APP_TECHNICAL
ACCOUNT
OTHER
```

## 32.2 Ticket Statuses

```text
OPEN
IN_PROGRESS
WAITING_FOR_USER
ESCALATED
RESOLVED
CLOSED
```

## 32.3 Safety Incident Levels

```text
LOW
MEDIUM
HIGH
CRITICAL
```

## 32.4 SOS Flow

```mermaid
flowchart TD
    A[User Presses SOS] --> B[Confirm Emergency]
    B --> C[Capture Current Location]
    C --> D[Create Critical Incident]
    D --> E[Attach Ride, Driver and Passenger]
    E --> F[Notify Operations]
    F --> G[Notify Emergency Contacts]
    G --> H[Show Emergency Call Options]
    H --> I[Preserve Audit Trail]
```

---

# 33. Security Requirements

## 33.1 API Security

- HTTPS in all non-local environments
- JWT authentication
- Refresh-token rotation
- Rate limiting
- Validation pipes
- SQL injection prevention
- CORS configuration
- Security headers
- Request size limits
- File upload validation
- Malware scanning integration point
- No sensitive data in logs
- Centralized exception handling

## 33.2 Data Security

- Encrypt sensitive fields where appropriate.
- Hash OTP values.
- Hash refresh tokens.
- Use signed file URLs.
- Restrict document access.
- Mask NIC and phone values in admin list pages.
- Separate public profile data from private identity data.
- Maintain deletion and retention policies.
- Record consent.

## 33.3 Fraud Controls

- Fake GPS detection
- Impossible travel detection
- Duplicate account detection
- Promo abuse limits
- Multiple failed card attempts
- Excessive cancellation monitoring
- Driver-passenger collusion signals
- Repeated no-show patterns
- Suspicious wallet adjustments
- Admin action monitoring

## 33.4 File Upload Rules

Allowed documents:

- JPG
- PNG
- PDF

Validation:

- MIME type
- File extension
- File size
- Image dimensions
- Virus/malware scan
- Randomized storage filename
- Access control
- Expiry metadata

---

# 34. Logging and Audit

## 34.1 Application Logs

Log:

- Request ID
- User ID
- Route
- Method
- Response status
- Processing duration
- Error code
- Ride ID if applicable

Do not log:

- OTP
- Access token
- Refresh token
- Full payment card data
- Sensitive uploaded document content

## 34.2 Audit Actions

Audit:

- Driver approval/rejection
- Driver suspension
- Fare adjustment
- Ride cancellation by admin
- Refund
- Wallet adjustment
- Pricing change
- Promotion change
- Role/permission change
- Safety incident update

---

# 35. Error Codes

Examples:

```text
AUTH_INVALID_OTP
AUTH_OTP_EXPIRED
AUTH_RATE_LIMITED
USER_SUSPENDED
DRIVER_NOT_APPROVED
DRIVER_DOCUMENT_EXPIRED
DRIVER_NOT_AVAILABLE
RIDE_NOT_FOUND
RIDE_INVALID_STATE
RIDE_ALREADY_ASSIGNED
RIDE_NO_DRIVER_AVAILABLE
RIDE_START_PIN_INVALID
PAYMENT_FAILED
PAYMENT_ALREADY_PROCESSED
PROMO_INVALID
PROMO_EXPIRED
PROMO_USAGE_LIMIT_REACHED
LOCATION_INVALID
PERMISSION_DENIED
VALIDATION_FAILED
INTERNAL_ERROR
```

---

# 36. Local Development Setup

## 36.1 Required Software

- Node.js LTS
- pnpm
- Flutter SDK
- Android Studio
- Xcode for iOS development on macOS
- PostgreSQL
- PostGIS
- Redis
- Docker Desktop
- Git
- Postman

## 36.2 Suggested Repository

```text
ride-platform/
├── backend/
├── admin-web/
├── mobile/
│   ├── apps/
│   │   ├── passenger_app/
│   │   └── driver_app/
│   └── packages/
├── docs/
├── postman/
├── scripts/
└── README.md
```

## 36.3 Local Docker Compose

```yaml
services:
  postgres:
    image: postgis/postgis:16-3.4
    environment:
      POSTGRES_DB: ride_platform
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  postgres_data:
```

## 36.4 Backend Environment Variables

```env
NODE_ENV=development
PORT=4000
API_PREFIX=api/v1

DATABASE_URL=postgresql://postgres:postgres@localhost:5432/ride_platform
REDIS_HOST=localhost
REDIS_PORT=6379

JWT_ACCESS_SECRET=change-me
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_SECRET=change-me
JWT_REFRESH_EXPIRES_IN=30d

OTP_EXPIRY_SECONDS=300
OTP_MAX_ATTEMPTS=5

GOOGLE_MAPS_API_KEY=
FIREBASE_PROJECT_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=

PAYMENT_GATEWAY=
PAYMENT_MERCHANT_ID=
PAYMENT_SECRET=

FILE_STORAGE_PROVIDER=local
FILE_STORAGE_PATH=./uploads
```

## 36.5 Backend Commands

```bash
pnpm install
pnpm migration:run
pnpm start:dev
pnpm test
pnpm test:e2e
pnpm lint
```

## 36.6 Flutter Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

---

# 37. Backend Coding Standards

- Enable TypeScript strict mode.
- Use DTOs for all API inputs.
- Validate using `class-validator` or Zod.
- Keep controllers thin.
- Put business logic in services/domain layer.
- Use repositories for database access.
- Avoid direct database calls from controllers.
- Use transactions for multi-step critical operations.
- Use domain-specific error classes.
- Write unit tests for business rules.
- Keep payment and wallet logic idempotent.
- Use enums for controlled states.
- Do not use magic strings.
- Document public APIs with Swagger.

---

# 38. Git Workflow

Branches:

```text
main
development
feature/<module>-<description>
bug/<module>-<description>
hotfix/<description>
```

Examples:

```text
feature/auth-otp-login
feature/ride-fare-estimate
feature/driver-dispatch
bug/payment-duplicate-webhook
```

Pull request requirements:

- Code review
- Lint pass
- Unit tests pass
- API tests pass
- No secrets
- Migration reviewed
- Screenshots for UI changes
- Acceptance criteria checked

---

# 39. Testing Strategy

## 39.1 Backend Unit Tests

Test:

- Fare calculation
- Promotion validation
- State transitions
- Driver eligibility
- Driver ranking
- Cancellation fee
- Wallet calculations
- Payment idempotency
- OTP rules

## 39.2 Backend Integration Tests

Test:

- Database transactions
- Ride creation
- Atomic driver assignment
- Payment processing
- Wallet entries
- Support ticket workflow
- Role permissions

## 39.3 API End-to-End Tests

Critical flows:

1. Passenger OTP login
2. Driver OTP login
3. Driver application
4. Admin approval
5. Driver goes online
6. Passenger estimates fare
7. Passenger creates ride
8. Driver receives offer
9. Driver accepts
10. Driver arrives
11. Start PIN validation
12. Trip starts
13. Trip completes
14. Payment completes
15. Passenger rates driver

## 39.4 Mobile Tests

- Widget tests
- State/controller tests
- Repository tests
- Navigation tests
- Permission denial tests
- App restart recovery
- Offline/reconnect tests
- Background location tests
- Push notification routing

## 39.5 Admin Web Tests

Use Playwright for:

- Admin login
- Driver approval
- Ride search
- Pricing update
- Promo creation
- Refund flow
- Wallet adjustment
- Role permission restrictions

## 39.6 Load Tests

Test:

- OTP endpoint
- Fare estimate
- Ride creation
- Driver location updates
- WebSocket connections
- Dispatch bursts
- Payment webhooks

Example targets for pilot testing:

```text
1,000 connected sockets
300 online drivers
50 ride requests per minute
100 location updates per second
```

These numbers must be adjusted according to expected launch scale.

---

# 40. Critical Race-Condition Test Cases

## 40.1 Two Drivers Accept Same Ride

Expected:

- Only one driver assigned
- Other driver receives offer-expired/already-assigned response

## 40.2 Passenger Creates Ride Twice

Expected:

- Same idempotency key returns same ride
- Passenger cannot have two incompatible active rides

## 40.3 Complete Trip Called Twice

Expected:

- Fare calculated once
- Wallet credited once
- Payment charged once

## 40.4 Duplicate Payment Webhook

Expected:

- Existing payment result returned
- No duplicate wallet transaction

## 40.5 Passenger Cancels While Driver Accepts

Expected:

- Atomic operation decides one valid result
- No assigned cancelled inconsistency

---

# 41. QA Acceptance Criteria for Core Ride Flow

A ride is considered successfully completed only when:

- Passenger is authenticated
- Pickup and destination are valid
- Fare estimate exists and is valid
- Ride is stored
- Eligible driver is selected
- Driver assignment is atomic
- Passenger receives driver information
- Driver location updates are visible
- Driver arrival is recorded
- Start PIN is verified
- Trip start time is recorded
- Trip route is tracked
- Final fare is calculated
- Payment result is recorded
- Driver wallet transaction is created
- Receipt is generated
- Passenger can submit rating
- All state changes exist in history

---

# 42. Development Phases

## Phase 1 — Discovery and Requirements

Deliverables:

- Business model
- User roles
- Service areas
- Vehicle categories
- Pricing rules
- Cancellation rules
- Payment model
- Driver commission model
- Safety process
- MVP scope
- Wireframe list
- SRS

## Phase 2 — UI/UX Design

Deliverables:

- Passenger user flow
- Driver user flow
- Admin flow
- Low-fidelity wireframes
- High-fidelity screens
- Design system
- Component library
- Clickable prototype
- Empty/error/loading states

## Phase 3 — Backend Foundation

Tasks:

- NestJS project
- Configuration
- PostgreSQL/PostGIS
- Redis
- Migrations
- Authentication
- Users
- Roles and permissions
- File upload
- Swagger
- Logging
- Error handling

## Phase 4 — Driver Onboarding

Tasks:

- Driver profile
- Vehicle profile
- Documents
- Application submission
- Admin verification
- Approval workflow
- Expiry tracking
- Driver status

## Phase 5 — Passenger Booking

Tasks:

- Places
- Pickup/dropoff
- Route details
- Fare estimate
- Vehicle categories
- Promo validation
- Ride creation
- Booking screen

## Phase 6 — Dispatch and Real-Time

Tasks:

- Driver location
- Redis GEO
- Heartbeat
- Driver eligibility
- Ranking
- Offer lifecycle
- Atomic assignment
- WebSocket events
- Live driver tracking

## Phase 7 — Trip Execution

Tasks:

- En route
- Arrived
- Start PIN
- Start trip
- Active route
- Complete trip
- Final fare
- Trip history

## Phase 8 — Payments and Wallet

Tasks:

- Payment methods
- Card tokenization
- Payment attempts
- Webhooks
- Cash accounting
- Driver wallet
- Commission
- Refunds
- Receipts

## Phase 9 — Admin Operations

Tasks:

- Dashboard
- Drivers
- Vehicles
- Rides
- Pricing
- Promotions
- Finance
- Support
- Incidents
- Audit logs

## Phase 10 — Safety, QA and Pilot Readiness

Tasks:

- SOS
- Trip sharing
- Emergency contacts
- Fraud checks
- Test automation
- Load tests
- Security tests
- UAT
- Bug fixing
- Pilot checklist

---

# 43. Suggested Development Timeline

| Phase | Estimated Duration |
|---|---:|
| Requirements and architecture | 2 weeks |
| UI/UX | 3–4 weeks |
| Backend foundation | 3 weeks |
| Driver onboarding | 3 weeks |
| Passenger booking | 4 weeks |
| Dispatch and real-time | 5 weeks |
| Trip execution | 3 weeks |
| Payments and wallet | 4 weeks |
| Admin dashboard | 4 weeks |
| Safety, QA and UAT | 4–5 weeks |

A lean MVP typically requires approximately **5–7 months**, depending on team size and payment/map integration complexity.

---

# 44. Team Structure

| Role | Suggested Count |
|---|---:|
| Product Owner / Business Analyst | 1 |
| UI/UX Designer | 1 |
| Flutter Developer | 2 |
| Backend Developer | 1–2 |
| Admin Web Developer | 1 |
| QA Engineer | 1 |
| DevOps/Infrastructure | Excluded from this document |
| Operations Representative | 1 |
| Finance/Compliance Representative | Part-time |

---

# 45. Product Backlog Epics

## EPIC-01 Authentication

- Passenger OTP login
- Driver OTP login
- Refresh token
- Logout
- Device sessions
- Rate limits

## EPIC-02 Passenger Profile

- Profile creation
- Saved places
- Emergency contacts
- Notification preferences
- Account deletion

## EPIC-03 Driver Onboarding

- Personal data
- Vehicle
- Documents
- Application
- Admin approval
- Expiry alerts

## EPIC-04 Maps and Locations

- Current location
- Place search
- Pin selection
- Route estimate
- Saved locations
- Service zones

## EPIC-05 Pricing

- Vehicle categories
- Pricing rules
- Fare estimate
- Final fare
- Cancellation fees
- Promotions

## EPIC-06 Ride Booking

- Create ride
- Search state
- Cancellation
- Active ride
- History

## EPIC-07 Dispatch

- Driver online status
- Redis GEO
- Eligibility
- Ranking
- Offers
- Atomic acceptance

## EPIC-08 Trip Execution

- En route
- Arrival
- Start PIN
- Start
- Location tracking
- Complete

## EPIC-09 Payments

- Cash
- Card tokens
- Charges
- Webhooks
- Refunds
- Receipts

## EPIC-10 Driver Wallet

- Earnings
- Commission
- Cash liability
- Adjustments
- Payout records

## EPIC-11 Notifications

- Push
- SMS
- In-app
- Notification history

## EPIC-12 Support and Safety

- Tickets
- Chat/messages
- SOS
- Trip sharing
- Incident handling

## EPIC-13 Admin Dashboard

- Driver verification
- Ride operations
- Pricing
- Promotions
- Payments
- Wallet
- Support
- Audit

## EPIC-14 QA and Security

- Automated tests
- Load tests
- Permission testing
- Fraud controls
- Security checks

---

# 46. Example User Stories

## Passenger Fare Estimate

**As a passenger**, I want to see ride options and estimated prices before booking, so that I can choose the correct vehicle type.

Acceptance criteria:

- Pickup and destination are required.
- Invalid locations are rejected.
- Available vehicle categories are returned.
- Each option includes ETA, distance, duration and estimated fare.
- Estimate has an expiry time.
- Fare is generated by backend.

## Driver Accept Ride

**As a driver**, I want to accept a nearby ride offer, so that I can complete the trip and earn income.

Acceptance criteria:

- Driver must be online and approved.
- Offer must not be expired.
- Driver must have no active ride.
- Only one driver can win the assignment.
- Passenger receives driver details.
- Other offers expire.

## Start Trip

**As a driver**, I want to verify a passenger PIN before starting, so that the correct passenger and ride are confirmed.

Acceptance criteria:

- Driver must be assigned.
- Driver must have arrived.
- PIN must be valid.
- Failed PIN attempts are limited.
- Trip start is recorded with time and location.
- Passenger receives trip-started event.

---

# 47. Definition of Done

A feature is done only when:

- Acceptance criteria are met
- Backend validation exists
- Authorization exists
- Unit tests are written
- API documentation is updated
- Mobile/admin UI handles loading, empty and error states
- Logs are adequate
- No sensitive data is exposed
- QA test cases pass
- Code review is complete
- Migration is included if required
- Product owner accepts the feature

---

# 48. Non-Functional Requirements

## Performance

- Normal API response under 500 ms excluding external providers
- Fare estimate under 2 seconds
- Driver assignment target under 20 seconds in healthy supply
- Socket event latency target under 2 seconds
- Active ride recovery after reconnect

## Availability Behaviour

- Graceful reconnect
- Retry temporary failures
- Prevent duplicate writes
- Mobile app restores active ride
- Driver location can buffer important updates briefly

## Scalability

- Stateless API services
- Redis for live locations
- Background queues
- Indexed geospatial queries
- Pagination for admin lists
- No unbounded database queries

## Maintainability

- Modular code
- Consistent naming
- API versioning
- Automated tests
- Central error handling
- Documented business rules

## Accessibility

- Readable font sizes
- Sufficient contrast
- Screen reader labels
- Large tap targets
- Avoid color-only state indication
- Sinhala/English localization readiness

---

# 49. Privacy and Data Retention Checklist

Define:

- Why each data field is collected
- Consent for location tracking
- Driver document retention period
- Ride history retention period
- Route/location retention period
- Support ticket retention
- Account deletion process
- Legal hold process
- Data export process
- Marketing notification opt-out
- Emergency data access policy

Location data should be collected only as required for operations, safety and dispute resolution.

---

# 50. Pilot Readiness Checklist

## Passenger

- Registration works
- Fare estimate accurate
- Ride booking stable
- Driver tracking works
- Cancellation works
- Payment works
- Receipt works
- Support works
- SOS works

## Driver

- Approval works
- Online/offline stable
- Background location stable
- Offers arrive
- Acceptance atomic
- Navigation action works
- Start PIN works
- Completion works
- Earnings correct

## Admin

- Drivers can be approved
- Active rides visible
- Ride timeline correct
- Pricing editable
- Refund process controlled
- Wallet adjustments audited
- Incidents manageable
- Reports exportable

## Technical

- Automated tests pass
- Duplicate payment prevented
- Duplicate ride prevented
- Load test completed
- Error monitoring configured in application
- Database backup strategy documented separately
- Privacy policy prepared
- Terms prepared
- Support process trained

---

# 51. Recommended Build Order

Build in this exact order:

```text
1. Requirements and business rules
2. UI/UX wireframes
3. Repository and code standards
4. Database foundation
5. Authentication
6. Passenger and driver profiles
7. Driver verification
8. Vehicle categories and pricing
9. Map/place selection
10. Fare estimate
11. Driver online location
12. Ride creation
13. Dispatch and offers
14. Atomic acceptance
15. Live tracking
16. Arrival and start PIN
17. Trip start and completion
18. Final fare
19. Cash accounting
20. Card payment
21. Driver wallet
22. Notifications
23. Admin operations
24. Support and SOS
25. Automated testing
26. UAT and pilot
```

Do not start advanced promotions, loyalty or delivery modules before the core ride lifecycle is stable.

---

# 52. Final Recommended Architecture

```text
Passenger Flutter App
        │
        ├── REST API
        ├── WebSocket
        └── Push Notifications
        │
        ▼
NestJS Modular Backend
        │
        ├── Auth
        ├── Users
        ├── Drivers
        ├── Vehicles
        ├── Rides
        ├── Dispatch
        ├── Pricing
        ├── Payments
        ├── Wallets
        ├── Notifications
        ├── Support
        └── Audit
        │
        ├── PostgreSQL + PostGIS
        ├── Redis GEO
        └── BullMQ Workers
        ▲
        │
Driver Flutter App

Next.js Admin Dashboard
        │
        └── Admin REST/WebSocket access
```

---

# 53. Final Development Recommendation

The first commercial version should focus on one reliable end-to-end flow:

```text
Passenger selects pickup and destination
→ System estimates fare
→ Passenger requests ride
→ Nearby eligible driver receives offer
→ One driver accepts
→ Passenger tracks driver
→ Driver arrives
→ Passenger verifies start PIN
→ Trip starts
→ Live location is tracked
→ Driver completes trip
→ Final fare is calculated
→ Payment is processed
→ Driver wallet is updated
→ Receipt and rating are completed
```

මෙම flow එක stable, secure සහ testable වන තුරු additional business modules add නොකරන්න.

The recommended initial stack is:

```text
Flutter Passenger App
Flutter Driver App
Next.js Admin Dashboard
NestJS + TypeScript Backend
PostgreSQL + PostGIS
Redis GEO
Socket.IO
BullMQ
Firebase Cloud Messaging
Google Maps Platform
PayHere or another tokenized payment gateway
```

---

# 54. Immediate Next Development Tasks

## Week 1

- Confirm business name
- Confirm passenger and driver user flows
- Confirm vehicle categories
- Confirm pricing rules
- Confirm commission model
- Confirm payment methods
- Create Git repositories
- Create Figma design system
- Create NestJS project
- Create PostgreSQL/PostGIS database
- Create Flutter passenger and driver apps
- Create Next.js admin project

## Week 2

- Build OTP authentication
- Build user and device session tables
- Build passenger profile
- Build driver profile
- Build vehicle and document entities
- Build admin RBAC
- Build basic admin driver application list

## Week 3

- Build driver application submission
- Build document upload
- Build admin verification
- Build vehicle categories
- Build pricing rules
- Build place search and map selection

## Week 4

- Build fare estimate
- Build driver online/offline
- Build driver location updates
- Store online driver locations in Redis GEO
- Begin ride creation and dispatch engine

---

**End of Development Blueprint**
