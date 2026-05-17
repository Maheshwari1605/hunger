const mongoose = require('mongoose');

const orderItemSchema = new mongoose.Schema(
  {
    menuItemId: { type: mongoose.Schema.Types.ObjectId, ref: 'MenuItem' },
    name: { type: String, required: true },
    price: { type: Number, required: true, min: 0 },
    quantity: { type: Number, required: true, min: 1 },
    notes: { type: String, default: '' },
  },
  { _id: false }
);

const orderSchema = new mongoose.Schema(
  {
    orderNumber: { type: String, unique: true, index: true },
    items: { type: [orderItemSchema], validate: (v) => v.length > 0 },
    subtotal: { type: Number, required: true, min: 0 },
    taxRate: { type: Number, default: 0.05 }, // 5% default
    taxAmount: { type: Number, required: true, min: 0 },
    discount: { type: Number, default: 0, min: 0 },
    total: { type: Number, required: true, min: 0 },
    paymentMethod: {
      type: String,
      enum: ['cash', 'card', 'upi', 'wallet'],
      required: true,
    },
    paymentStatus: {
      type: String,
      enum: ['paid', 'pending', 'refunded', 'void'],
      default: 'paid',
    },
    kitchenStatus: {
      type: String,
      enum: ['queued', 'preparing', 'ready', 'served'],
      default: 'queued',
    },
    cashierId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    cashierName: { type: String, default: '' },
    customer: {
      name: { type: String, default: '' },
      phone: { type: String, default: '' },
    },
    outletId: { type: String, default: 'default', index: true },
  },
  { timestamps: true }
);

orderSchema.pre('validate', function (next) {
  if (!this.orderNumber) {
    // Sortable, human-friendly: yymmdd-randomShort
    const d = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const stamp = `${String(d.getFullYear()).slice(2)}${pad(d.getMonth() + 1)}${pad(d.getDate())}`;
    const rand = Math.random().toString(36).slice(2, 7).toUpperCase();
    this.orderNumber = `${stamp}-${rand}`;
  }
  next();
});

module.exports = mongoose.model('Order', orderSchema);
