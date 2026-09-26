# Passenger Premier Cabs Welcome + Auth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Premier Cabs welcome screen and restyle passenger login with Wine Red `#861619` + Shine Black `#0B0B0D`.

**Architecture:** Separate `/welcome` route as `initialLocation`; Get Started navigates to existing `/login`. Shared theme gains Premier Cabs tokens; login OTP API unchanged.

**Tech Stack:** Flutter, go_router, flutter_riverpod, asset images

## Global Constraints

- Colors: Wine Red `#861619`, Shine Black `#0B0B0D`, white, gray
- OTP endpoints and `userType: PASSENGER` unchanged
- Home/map/ride full rebrand out of scope
- Carousel dots visual-only (no real pages)

## File map

| File | Responsibility |
|------|----------------|
| `apps/passenger/assets/images/pcablogo.png` | Brand logo |
| `apps/passenger/assets/images/premier_hero_car.png` | Welcome hero car |
| `apps/passenger/pubspec.yaml` | Register assets |
| `apps/passenger/lib/core/theme.dart` | Brand color tokens + primary button theme |
| `apps/passenger/lib/features/auth/welcome_screen.dart` | Welcome UI |
| `apps/passenger/lib/features/auth/login_screen.dart` | Premier Cabs login restyle |
| `apps/passenger/lib/main.dart` | `/welcome` route + initialLocation |

---

### Task 1: Assets + theme tokens

**Files:**
- Create: `apps/passenger/assets/images/pcablogo.png`
- Create: `apps/passenger/assets/images/premier_hero_car.png`
- Modify: `apps/passenger/pubspec.yaml`
- Modify: `apps/passenger/lib/core/theme.dart`

- [x] **Step 1: Copy assets and register in pubspec**
- [x] **Step 2: Add Premier Cabs colors; set theme primary to Wine Red**
- [x] **Step 3: Verify analyze**

---

### Task 2: Welcome screen + routing

**Files:**
- Create: `apps/passenger/lib/features/auth/welcome_screen.dart`
- Modify: `apps/passenger/lib/main.dart`

**Interfaces:**
- Produces: `WelcomeScreen` StatelessWidget; Get Started calls `context.go('/login')`

- [x] **Step 1: Implement WelcomeScreen** matching full mock (logo, headline with Premium in wine, features, hero car, dots, Get Started pill, trust footer) on `pcBlack`.
- [x] **Step 2: Wire route** — `initialLocation: '/welcome'`, add `GoRoute(path: '/welcome', ...)`, import welcome screen, set `title: 'Premier Cabs'`.
- [x] **Step 3: Analyze**

---

### Task 3: Restyle LoginScreen

**Files:**
- Modify: `apps/passenger/lib/features/auth/login_screen.dart`

- [x] **Step 1: Restyle** — `pcBlack` background, logo image, white card, `pcWine` message/accent colors; keep OTP request/verify logic identical.
- [x] **Step 2: Analyze auth folder**

---

### Task 4: Manual verify checklist

- [x] App opens on Welcome with logo + car + Get Started (widget test)
- [ ] Get Started → Login with Wine Red button (manual on device)
- [ ] Send code / Verify still work against existing API (manual)
