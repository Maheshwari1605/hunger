const router = require('express').Router();
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');
const ctrl = require('../controllers/authController');

router.post('/login', ctrl.login);

// First-run bootstrap and admin-managed user creation both flow through here.
// In production, lock this behind an admin token or a one-shot bootstrap flag.
router.post('/register', ctrl.register);

router.get('/me', authenticate, ctrl.me);
router.get('/users', authenticate, requireRole('admin'), ctrl.listUsers);

module.exports = router;
