const router = require('express').Router();
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');
const ctrl = require('../controllers/reportController');

// Reports are admin-only by default.
router.get('/daily', authenticate, requireRole('admin'), ctrl.dailySales);
router.get('/monthly', authenticate, requireRole('admin'), ctrl.monthlySales);
router.get('/best-selling', authenticate, requireRole('admin'), ctrl.bestSelling);
router.get('/payment-mix', authenticate, requireRole('admin'), ctrl.paymentMixSummary);
router.get('/category-summary', authenticate, requireRole('admin'), ctrl.categorySummary);
router.get('/item-summary', authenticate, requireRole('admin'), ctrl.itemSummary);
router.get('/order-summary', authenticate, requireRole('admin'), ctrl.orderSummary);
router.get('/employee-summary', authenticate, requireRole('admin'), ctrl.employeeSummary);

module.exports = router;
