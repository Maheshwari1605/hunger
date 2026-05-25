const mongoose = require('mongoose');

// One settings doc per outlet. Use upsert with outletId for atomic reads.
const settingsSchema = new mongoose.Schema(
  {
    outletId: { type: String, default: 'default', unique: true, index: true },
    // Tax-free POS — always 0. Field is kept for backward compatibility.
    taxRate: { type: Number, default: 0, min: 0, max: 1 },
    currency: { type: String, default: '₹' },
    cafeName: { type: String, default: 'Hunger Cafe' },
    address: { type: String, default: '' },
    phone: { type: String, default: '' },
    gstNumber: { type: String, default: '' },
    receiptFooter: { type: String, default: 'Thank you — visit again!' },
  },
  { timestamps: true }
);

settingsSchema.statics.getOrCreate = async function (outletId = 'default') {
  let doc = await this.findOne({ outletId });
  if (!doc) doc = await this.create({ outletId });
  return doc;
};

module.exports = mongoose.model('Settings', settingsSchema);
