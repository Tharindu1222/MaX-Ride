# Driver Welcome + Auth UI Design

**Date:** 2026-08-21  
**App:** `apps/driver` (MaX Ride Driver)

## Goal

First launch shows a car-cabin welcome screen with a **Start** button. Tapping Start navigates to the existing phone + OTP login flow, with light visual polish.

## Flow

1. App opens at `/welcome`
2. Welcome: full-bleed illustrated cabin + brand + **Start**
3. Start → `/login`
4. Login: phone → Send OTP → OTP → Verify → `/` (home)

## Approach

Separate welcome route; keep existing `LoginScreen` OTP API behavior (`/auth/otp/request`, `/auth/otp/verify`, `userType: DRIVER`).

## Visual

- **Welcome:** Bundled illustrated cabin (`assets/images/driver_cabin_welcome.png`), bottom gradient scrim, amber **MaX Ride** / grey **Driver**, amber **Start** button
- **Login:** Existing navy→ink gradient; polish spacing, hierarchy, loading/error presentation; white inputs; amber primary actions

## Out of scope

Driver onboarding form, home map, real SMS provider changes, session persistence beyond existing tokens.
