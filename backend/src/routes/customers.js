const router = require('express').Router();
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');
const ctrl = require('../controllers/customerController');

router.get('/', authenticate, ctrl.list);
router.get('/lookup', authenticate, ctrl.lookupByPhone);
router.post('/', authenticate, requireRole('admin', 'cashier'), ctrl.create);
router.put('/:id', authenticate, requireRole('admin'), ctrl.update);
router.delete('/:id', authenticate, requireRole('admin'), ctrl.remove);

module.exports = router;
