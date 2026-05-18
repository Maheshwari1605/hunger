const mongoose = require('mongoose');

const entrySchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ['expense', 'withdrawal', 'topup'],
      required: true,
    },
    amount: { type: Number, required: true, min: 0 },
    note: { type: String, default: '' },
    at: { type: Date, default: Date.now },
    byId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    byName: { type: String, default: '' },
  },
  { _id: true }
);

const cashSessionSchema = new mongoose.Schema(
  {
    openedAt: { type: Date, default: Date.now },
    closedAt: { type: Date, default: null },
    openedById: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    openedByName: { type: String, default: '' },
    closedById: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    closedByName: { type: String, default: '' },
    openingBalance: { type: Number, required: true, min: 0 },
    closingBalance: { type: Number, default: null },
    entries: { type: [entrySchema], default: [] },
    outletId: { type: String, default: 'default', index: true },
  },
  { timestamps: true }
);

cashSessionSchema.statics.currentOpen = function (outletId = 'default') {
  return this.findOne({ outletId, closedAt: null }).sort({ openedAt: -1 });
};

module.exports = mongoose.model('CashSession', cashSessionSchema);
