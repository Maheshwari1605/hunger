# Hunger Cafe — Backend API

Node.js + Express + MongoDB REST API for the Hunger Cafe POS & Management System.

## Quick start

```bash
cd backend
cp .env.example .env        # then edit JWT_SECRET and MONGO_URI
npm install
npm run seed                # creates default users + loads data/menu.xlsx (248 items, 22 categories)
npm run dev                 # or: npm start
```

Server listens on `http://localhost:4000` by default.

## Default seeded users

| Role    | Email                       | Password    |
|---------|-----------------------------|-------------|
| admin   | admin@hunger.cafe        | admin123    |
| cashier | cashier@hunger.cafe      | cashier123  |
| kitchen | kitchen@hunger.cafe      | kitchen123  |

> Change these immediately in any non-local environment.

## API surface

All authenticated routes expect `Authorization: Bearer <JWT>`.

### Auth
- `POST /api/auth/login` — `{ email, password }` → `{ token, user }`
- `POST /api/auth/register` — bootstrap users (lock down in prod)
- `GET  /api/auth/me` — current user
- `GET  /api/auth/users` — admin only

### Menu
- `GET    /api/menu/items` — list (filters: `category`, `q`, `available`)
- `GET    /api/menu/items/:id`
- `POST   /api/menu/items` — **admin**
- `PUT    /api/menu/items/:id` — **admin**
- `DELETE /api/menu/items/:id` — **admin**
- `GET    /api/menu/categories`
- `POST   /api/menu/categories` — **admin**
- `POST   /api/menu/upload` — **admin**, multipart `file=<xlsx>` (bulk upsert)

Excel columns (case-insensitive): `name, category, price, sku, description, tags, available, stock`

> The bundled menu at `backend/data/menu.xlsx` uses a richer schema (Sr.No / Item Name / Category / Veg / SMALL / medium / cheese-small / cheese-medium) and is ingested by `src/utils/menuImporter.js`, which expands each row into one MenuItem per priced size variant.

### Orders
- `POST  /api/orders` — **admin/cashier** — creates an order. Server re-derives prices from the menu.
- `GET   /api/orders` — list with filters `from`, `to`, `status`, `kitchenStatus`, `limit`
- `GET   /api/orders/:id`
- `PATCH /api/orders/:id/kitchen` — **admin/kitchen** — `{ kitchenStatus: queued|preparing|ready|served }`
- `PATCH /api/orders/:id/void` — **admin**

### Reports (admin only)
- `GET /api/reports/daily?date=YYYY-MM-DD`
- `GET /api/reports/monthly?month=YYYY-MM`
- `GET /api/reports/best-selling?from=&to=&limit=`
- `GET /api/reports/payment-mix?from=&to=`

## Architecture notes

- **Auth:** JWT (`HS256`), 8h expiry by default. Passwords hashed with bcrypt (cost 12).
- **RBAC:** `requireRole(...roles)` middleware after `authenticate`.
- **Pricing integrity:** order totals are computed server-side from the current menu — cart prices from the client are ignored.
- **Inventory hook:** `MenuItem.stock` decrements on order creation when tracked (`stock !== null`).
- **Multi-outlet:** every `User`, `MenuItem`, and `Order` carries an `outletId` for future tenant separation.
- **Security:** Helmet, CORS allowlist, rate-limit on `/api/*`.

## Folder structure

```
backend/
├── src/
│   ├── server.js
│   ├── config/db.js
│   ├── models/      (User, Category, MenuItem, Order)
│   ├── middleware/  (auth, roles)
│   ├── routes/      (auth, menu, orders, reports)
│   ├── controllers/
│   └── utils/       (excelParser, seed)
├── .env.example
└── package.json
```
