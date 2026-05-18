require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const connectDB = require('./config/db');
const authRoutes = require('./routes/auth');
const menuRoutes = require('./routes/menu');
const orderRoutes = require('./routes/orders');
const reportRoutes = require('./routes/reports');
const customerRoutes = require('./routes/customers');
const tableRoutes = require('./routes/tables');
const cashRoutes = require('./routes/cash');
const settingsRoutes = require('./routes/settings');

const app = express();

const allowedOrigins = (process.env.ALLOWED_ORIGINS || '').split(',').filter(Boolean);

function isLocalDevOrigin(origin) {
  if (process.env.NODE_ENV !== 'development') return false;
  try {
    const { hostname } = new URL(origin);
    return hostname === 'localhost' || hostname === '127.0.0.1';
  } catch {
    return false;
  }
}

// Security & infra middleware
app.use(helmet());
app.use(
  cors({
    origin(origin, callback) {
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes(origin) || isLocalDevOrigin(origin)) {
        return callback(null, true);
      }
      callback(new Error(`CORS blocked origin: ${origin}`));
    },
    credentials: true,
  })
);
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

// Basic rate limiting (helps with brute-force on /auth)
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// Health check
app.get('/health', (_req, res) => res.json({ status: 'ok', ts: Date.now() }));

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/menu', menuRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/tables', tableRoutes);
app.use('/api/cash', cashRoutes);
app.use('/api/settings', settingsRoutes);

// 404
app.use((req, res) => res.status(404).json({ error: 'Route not found' }));

// Central error handler
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, _next) => {
  console.error('[ERROR]', err);
  const status = err.status || 500;
  res.status(status).json({
    error: err.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});

const PORT = process.env.PORT || 4000;

connectDB()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Hunger Cafe API listening on http://localhost:${PORT}`);
    });
  })
  .catch((err) => {
    console.error('Failed to start server:', err);
    process.exit(1);
  });
