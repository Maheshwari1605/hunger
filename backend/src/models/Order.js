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
    billNumber: { type: String, index: true }, // sequential per outlet per day
    orderType: {
      type: String,
      enum: ['dine-in', 'delivery', 'pick-up'],
      default: 'dine-in',
      index: true,
    },
    tableId: { type: mongoose.Schema.Types.ObjectId, ref: 'Table', default: null },
    tableLabel: { type: String, default: '' }, // denormalized for display
    customerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer', default: null },
    customer: {
      name: { type: String, default: '' },
      phone: { type: String, default: '' },
      address: { type: String, default: '' }, // for delivery
    },
    items: { type: [orderItemSchema], validate: (v) => v.length > 0 },
    subtotal: { type: Number, required: true, min: 0 },
    discountType: { type: String, enum: ['fixed', 'percent'], default: 'fixed' },
    discountValue: { type: Number, default: 0, min: 0 },
    discount: { type: Number, default: 0, min: 0 }, // computed absolute amount
    // Tax-free POS — both fields kept for backward compatibility but always 0.
    taxRate: { type: Number, default: 0 },
    taxAmount: { type: Number, required: true, min: 0, default: 0 },
    total: { type: Number, required: true, min: 0 },
    paymentMethod: {
      type: String,
      enum: ['cash', 'card', 'upi', 'wallet', ''],
      default: '',
    },
    paymentStatus: {
      type: String,
      enum: ['open', 'paid', 'pending', 'refunded', 'void'],
      default: 'paid',
      index: true,
    },
    kitchenStatus: {
      type: String,
      enum: ['queued', 'preparing', 'ready', 'served'],
      default: 'queued',
    },
    cashierId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    cashierName: { type: String, default: '' },
    outletId: { type: String, default: 'default', index: true },
  },
  { timestamps: true }
);

orderSchema.pre('validate', function (next) {
  if (!this.orderNumber) {
    const d = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const stamp = `${String(d.getFullYear()).slice(2)}${pad(d.getMonth() + 1)}${pad(d.getDate())}`;
    const rand = Math.random().toString(36).slice(2, 7).toUpperCase();
    this.orderNumber = `${stamp}-${rand}`;
  }
  next();
});

module.exports = mongoose.model('Order', orderSchema);
