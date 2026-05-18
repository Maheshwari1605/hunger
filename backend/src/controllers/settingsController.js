const Settings = require('../models/Settings');

exports.get = async (req, res, next) => {
  try {
    const s = await Settings.getOrCreate(req.user.outletId);
    res.json({ settings: s });
  } catch (err) {
    next(err);
  }
};

exports.update = async (req, res, next) => {
  try {
    const { taxRate, currency, cafeName, address, phone, gstNumber, receiptFooter } = req.body;
    const $set = {};
    if (taxRate !== undefined) {
      const n = Number(taxRate);
      if (Number.isNaN(n) || n < 0 || n > 1) {
        return res.status(400).json({ error: 'taxRate must be 0..1 (e.g. 0.05 for 5%)' });
      }
      $set.taxRate = n;
    }
    if (currency !== undefined) $set.currency = currency;
    if (cafeName !== undefined) $set.cafeName = cafeName;
    if (address !== undefined) $set.address = address;
    if (phone !== undefined) $set.phone = phone;
    if (gstNumber !== undefined) $set.gstNumber = gstNumber;
    if (receiptFooter !== undefined) $set.receiptFooter = receiptFooter;
    const s = await Settings.findOneAndUpdate(
      { outletId: req.user.outletId },
      { $set, $setOnInsert: { outletId: req.user.outletId } },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
    res.json({ settings: s });
  } catch (err) {
    next(err);
  }
};
