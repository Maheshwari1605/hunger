# Hunger Cafe — POS & Management System

Full-stack scaffold matching the BRD: Flutter client + Node.js/Express API + MongoDB.

```
hunger/
├── backend/     Node.js + Express + Mongoose
└── frontend/    Flutter (mobile/web/desktop)
```

## What's covered (MVP scope from the BRD)

- **POS Billing** — item grid, cart, discount, tax (5% default), payment method (cash/card/UPI), printable receipt. Server re-derives prices from the menu so cart amounts cannot be tampered with.
- **Menu Management** — full CRUD by category, plus bulk Excel upload (`POST /api/menu/upload`, multipart `file`). Excel columns: `name, category, price, sku, description, tags, available, stock` (upserts by SKU when present, else by name+category).
- **Reports & Analytics** — daily summary + hourly histogram, monthly revenue by day, best-selling items, payment method mix.
- **Auth & RBAC** — JWT login; three roles: `admin`, `cashier`, `kitchen`. Server enforces role per route; UI hides tabs the role can't use.
- **Kitchen Display** — kitchen role sees active orders, advances `queued → preparing → ready → served`.
- **Multi-outlet ready** — every user / menu item / order carries `outletId` for future tenant separation.

## Getting started

### 1. Backend

```bash
cd backend
cp .env.example .env       # set JWT_SECRET and MONGO_URI
npm install
npm run seed               # creates admin/cashier/kitchen users + starter menu
npm run dev                # http://localhost:4000
```

Health check: `curl http://localhost:4000/health`

### 2. Frontend

```bash
cd ../frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:4000
```

Sign in with one of the seeded users (see `backend/README.md`).

## Architecture

```
┌────────────────────────┐       HTTPS / JSON       ┌────────────────────────┐
│  Flutter Client        │  ─────────────────────►  │  Node.js + Express     │
│  (web / iOS / Android) │  ◄─────────────────────  │  JWT auth, RBAC        │
└────────────────────────┘                          │  Mongoose models       │
        ▲                                           └──────────┬─────────────┘
        │  SharedPreferences (token)                           │
        ▼                                                      ▼
   Provider (state)                                     ┌──────────────┐
                                                         │  MongoDB     │
                                                         └──────────────┘
```

### Performance targets (per BRD)

- **<2s response time** — Express routes are read-cached at the DB layer (Mongoose autoIndex in dev, manual indexes on `MenuItem.name/category` and `Order.outletId/createdAt`).
- **Encrypted data in transit** — assumes TLS termination at the reverse proxy (Nginx/Caddy); passwords are bcrypt-hashed (cost 12).
- **Multi-outlet ready** — outlet scoping is in the schema; add per-outlet filtering in controllers when adding a second outlet.

## API reference

See [`backend/README.md`](./backend/README.md) for the full route map. Auth header on every protected request:

```
Authorization: Bearer <jwt>
```

## What's intentionally out of scope here (future enhancements from the BRD)

- AI-driven sales insights, inventory automation
- Customer loyalty system
- WhatsApp billing / messaging integrations
- Full inventory module beyond the lightweight `MenuItem.stock` hook

## Tech stack

| Layer       | Choice                                    |
|-------------|-------------------------------------------|
| Mobile/Web  | Flutter 3, Provider, `http`, `fl_chart`   |
| API         | Node.js 18+, Express 4, Helmet, CORS, rate-limit |
| Auth        | JWT (`jsonwebtoken`), bcrypt              |
| DB          | MongoDB (Mongoose 8)                      |
| Excel       | `xlsx`, Multer (memory storage, 5MB cap)  |

## Development tips

- **Frontend `API_BASE_URL`** is read at compile time via `--dart-define`. For the Android emulator, use `http://10.0.2.2:4000`. For a real device on the same Wi-Fi, use your machine's LAN IP.
- **Seeding** is idempotent — running `npm run seed` again will upsert without duplicating.
- **Adding a new role** — add it to `User.ROLES`, then update `requireRole(...)` calls and the role check in `HomeScreen`.
# hunger
