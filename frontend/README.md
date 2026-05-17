# Hunger Cafe — Flutter Client

Flutter app for the Hunger Cafe POS & Management System. Single codebase targets web, desktop, Android, and iOS.

## Quick start

```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:4000
```

Android emulator hosts: use `http://10.0.2.2:4000` for `API_BASE_URL`.
Real device: use your machine's LAN IP.

## Default logins (after seeding the backend)

- Admin   — `admin@hunger.cafe` / `admin123`
- Cashier — `cashier@hunger.cafe` / `cashier123`
- Kitchen — `kitchen@hunger.cafe` / `kitchen123`

## What's inside

- **`lib/main.dart`** — app entry, theme, provider wiring.
- **`lib/screens/`**
  - `login_screen.dart` — email/password sign-in.
  - `home_screen.dart` — role-aware bottom nav.
  - `pos_screen.dart` — POS billing: menu grid, cart, discount, tax, payment method, receipt dialog.
  - `menu_screen.dart` — Menu CRUD (admin).
  - `kitchen_screen.dart` — Kitchen display system; auto-refreshes; advances `queued → preparing → ready → served`.
  - `reports_screen.dart` — Daily totals, monthly revenue chart, best-sellers, payment mix.
- **`lib/services/`** — `ApiClient` + per-domain services (auth, menu, orders, reports).
- **`lib/models/`** — `AppUser`, `MenuItem`, `OrderSummary`, `CartLine`.
- **`lib/widgets/receipt_dialog.dart`** — printable receipt view.

## Role-based UI

`HomeScreen` builds the bottom navigation from the current user's role:

| Role    | POS | Menu | Kitchen | Reports |
|---------|-----|------|---------|---------|
| admin   | ✓   | ✓    | ✓       | ✓       |
| cashier | ✓   |      |         |         |
| kitchen |     |      | ✓       |         |

## Build for the web

```bash
flutter build web --dart-define=API_BASE_URL=https://api.your-domain.com
```

## Notes

- `ApiClient` persists the JWT in `SharedPreferences` and re-hydrates the user on cold start via `/api/auth/me`.
- All order totals are recomputed server-side; the client values are display-only.
