# Passenger Premier Cabs Welcome + Auth UI Design

**Date:** 2026-09-21  
**App:** `apps/passenger` (rebrand entry: Premier Cabs)

## Goal

First launch shows a dark premium welcome screen matching the provided mock (logo, Honda hero, features, Get Started). Tapping Get Started opens the existing phone + OTP login, restyled to the same Premier Cabs palette.

## Brand & colors

| Role | Hex | Use |
|------|-----|-----|
| Wine Red | `#861619` | Accents, “Premium”, CTA, icons, active dot |
| Shine Black | `#0B0B0D` | Welcome + login backgrounds |
| White | `#FFFFFF` | Primary text, card surfaces |
| Gray | `#9A9A9A` (approx) | Secondary text, inactive dots |

## Flow

1. App opens at `/welcome`
2. Welcome: logo + headline + features + car hero + Get Started + trust footer
3. Get Started → `/login`
4. Login: phone → Send OTP → OTP → Verify → `/select` (unchanged)

## Approach

Separate welcome route; keep existing `LoginScreen` OTP API behavior (`/auth/otp/request`, `/auth/otp/verify`, `userType: PASSENGER`). Update shared theme tokens so login (and later screens that use theme) pick up Wine Red / Shine Black.

## Visual — Welcome (full mock)

Top → bottom on Shine Black:

1. Centered `pcablogo.png` (Premier Cabs wordmark + tagline in asset)
2. Headline: “Your **Premium** Journey Begins Here.” (`Premium` in Wine Red)
3. Thin Wine Red divider
4. Features with Wine Red icons: Luxury Rides · Anytime · Anywhere
5. Hero car image (bundled from `apps/Screenshot 2026-09-21 at 21.44.08.png`)
6. Three carousel dots (first active) — **visual only**, no real pages yet
7. Pill **Get Started** button (Wine Red gradient + arrow circle) → `/login`
8. Footer trust row: Safe & Secure · On Time · Premium Experience

## Visual — Login

- Shine Black background (replace forest green gradient)
- Premier Cabs logo (or compact brand mark) instead of “MaX Ride” title
- White/light card for phone + OTP fields
- Primary actions Wine Red (`Send code` / `Verify & continue`)
- OTP logic and mock defaults unchanged

## Assets

Copy into `apps/passenger/assets/images/` and register in `pubspec.yaml`:

- `pcablogo.png` ← `apps/pcablogo.png`
- `premier_hero_car.png` ← `apps/Screenshot 2026-09-21 at 21.44.08.png` (renamed for clean asset path)

## Files

- New: `lib/features/auth/welcome_screen.dart`
- Update: `lib/main.dart` (`initialLocation: '/welcome'`, route)
- Update: `lib/core/theme.dart` (palette + primary buttons)
- Update: `lib/features/auth/login_screen.dart` (Premier Cabs restyle)
- Update: `pubspec.yaml` (assets)

## Out of scope

- Home / map / ride / profile full rebrand
- Real multi-page onboarding carousel
- Driver app
- Auth API or OTP provider changes
