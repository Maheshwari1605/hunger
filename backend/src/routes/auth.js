const router = require('express').Router();
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');
const ctrl = require('../controllers/authController');

router.post('/login', ctrl.login);

// First-run bootstrap and admin-managed user creation both flow through here.
// In production, lock this behind an admin token or a one-shot bootstrap flag.
router.post('/register', ctrl.register);

router.get('/me', authenticate, ctrl.me);
router.post('/change-password', authenticate, ctrl.changePassword);

// Admin-only user management.
router.get('/users', authenticate, requireRole('admin'), ctrl.listUsers);
router.post('/users', authenticate, requireRole('admin'), ctrl.createUser);
router.put('/users/:id', authenticate, requireRole('admin'), ctrl.updateUser);

module.exports = router;
