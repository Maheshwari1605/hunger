const router = require('express').Router();
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');
const ctrl = require('../controllers/cashController');

router.get('/current', authenticate, ctrl.current);
router.post('/open', authenticate, requireRole('admin', 'cashier'), ctrl.open);
router.post('/close', authenticate, requireRole('admin', 'cashier'), ctrl.close);
router.post('/entry', authenticate, requireRole('admin', 'cashier'), ctrl.addEntry);
router.get('/history', authenticate, requireRole('admin'), ctrl.history);

module.exports = router;
