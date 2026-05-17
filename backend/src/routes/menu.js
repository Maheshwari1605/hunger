const router = require('express').Router();
const multer = require('multer');
const authenticate = require('../middleware/auth');
const requireRole = require('../middleware/roles');
const ctrl = require('../controllers/menuController');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

// Reads — any authenticated user
router.get('/items', authenticate, ctrl.listItems);
router.get('/items/:id', authenticate, ctrl.getItem);
router.get('/categories', authenticate, ctrl.listCategories);

// Writes — admin only
router.post('/items', authenticate, requireRole('admin'), ctrl.createItem);
router.put('/items/:id', authenticate, requireRole('admin'), ctrl.updateItem);
router.delete('/items/:id', authenticate, requireRole('admin'), ctrl.deleteItem);
router.post('/categories', authenticate, requireRole('admin'), ctrl.createCategory);

router.post(
  '/upload',
  authenticate,
  requireRole('admin'),
  upload.single('file'),
  ctrl.bulkUpload
);

module.exports = router;
