const mongoose = require('mongoose');

const tableSchema = new mongoose.Schema(
  {
    label: { type: String, required: true, trim: true },
    capacity: { type: Number, default: 4 },
    active: { type: Boolean, default: true },
    outletId: { type: String, default: 'default', index: true },
  },
  { timestamps: true }
);

tableSchema.index({ outletId: 1, label: 1 }, { unique: true });

module.exports = mongoose.model('Table', tableSchema);
