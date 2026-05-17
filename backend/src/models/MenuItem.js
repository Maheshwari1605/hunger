const mongoose = require('mongoose');

const menuItemSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, index: true },
    description: { type: String, default: '' },
    price: { type: Number, required: true, min: 0 },
    category: { type: String, required: true, trim: true, index: true },
    sku: { type: String, trim: true, index: true },
    available: { type: Boolean, default: true },
    tags: [{ type: String, trim: true }],
    imageUrl: { type: String, default: '' },
    // Lightweight inventory hooks — real inventory would have a separate collection.
    stock: { type: Number, default: null }, // null = not tracked
    outletId: { type: String, default: 'default', index: true },
  },
  { timestamps: true }
);

menuItemSchema.index({ name: 'text', description: 'text', tags: 'text' });

module.exports = mongoose.model('MenuItem', menuItemSchema);
