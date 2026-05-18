const mongoose = require('mongoose');

const customerSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    phone: { type: String, required: true, trim: true, index: true },
    email: { type: String, default: '', trim: true, lowercase: true },
    address: { type: String, default: '' },
    notes: { type: String, default: '' },
    totalOrders: { type: Number, default: 0 },
    totalSpent: { type: Number, default: 0 },
    lastOrderAt: { type: Date, default: null },
    outletId: { type: String, default: 'default', index: true },
  },
  { timestamps: true }
);

customerSchema.index({ outletId: 1, phone: 1 }, { unique: true });

module.exports = mongoose.model('Customer', customerSchema);
