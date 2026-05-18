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

## Offline support

The app keeps working when the network drops, with the following behavior:

- **Menu cache** — every successful menu fetch is saved to `SharedPreferences`. When offline, `MenuService.list()` returns the cached items so the POS grid still renders.
- **Order queue** — if `POST /api/orders` fails with a network error (not an HTTP error), the order payload is appended to a local queue and the cashier sees a receipt marked *"Saved offline — will sync when online"*.
- **Sync** — `SyncService` listens to `connectivity_plus` and tries to flush the queue every 30 seconds while online, and immediately when connectivity returns. Successfully synced orders are removed from the queue; the server re-derives prices from the live menu at sync time.
- **UI indicator** — a cloud icon in the app bar shows online/offline status, plus an orange badge with the count of orders still waiting to sync. Tapping it opens a sheet with a manual **Sync now** button and the last sync error if any.

What is NOT covered offline: login, reports, kitchen status updates, menu admin (CRUD), Excel uploads. Those still require a live connection.
