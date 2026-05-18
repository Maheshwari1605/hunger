const router = require('express').Router();
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');
const ctrl = require('../controllers/settingsController');

router.get('/', authenticate, ctrl.get);
router.put('/', authenticate, requireRole('admin'), ctrl.update);

module.exports = router;
