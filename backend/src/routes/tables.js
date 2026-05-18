const router = require('express').Router();
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');
const ctrl = require('../controllers/tableController');

router.get('/', authenticate, ctrl.list);
router.post('/', authenticate, requireRole('admin'), ctrl.create);
router.put('/:id', authenticate, requireRole('admin'), ctrl.update);
router.delete('/:id', authenticate, requireRole('admin'), ctrl.remove);

module.exports = router;
