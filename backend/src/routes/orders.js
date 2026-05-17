const router = require('express').Router();
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');
const ctrl = require('../controllers/orderController');

// Cashier (and admin) can take orders
router.post('/', authenticate, requireRole('admin', 'cashier'), ctrl.createOrder);

// Listing — any authenticated user (kitchen needs it for the queue)
router.get('/', authenticate, ctrl.listOrders);
router.get('/:id', authenticate, ctrl.getOrder);

// Kitchen status updates — kitchen and admin
router.patch(
  '/:id/kitchen',
  authenticate,
  requireRole('admin', 'kitchen'),
  ctrl.updateKitchenStatus
);

// Voiding/refunding — admin only
router.patch('/:id/void', authenticate, requireRole('admin'), ctrl.voidOrder);

module.exports = router;
