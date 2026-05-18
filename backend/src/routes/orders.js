const router = require('express').Router();
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');
const ctrl = require('../controllers/orderController');

router.post('/', authenticate, requireRole('admin', 'cashier'), ctrl.createOrder);
router.post('/:id/settle', authenticate, requireRole('admin', 'cashier'), ctrl.settleOrder);
router.get('/', authenticate, ctrl.listOrders);
router.get('/:id', authenticate, ctrl.getOrder);
router.patch(
  '/:id/kitchen',
  authenticate,
  requireRole('admin', 'kitchen'),
  ctrl.updateKitchenStatus
);
router.patch('/:id/void', authenticate, requireRole('admin'), ctrl.voidOrder);

module.exports = router;
