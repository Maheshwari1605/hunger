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
    const { currency, cafeName, address, phone, gstNumber, receiptFooter } = req.body;
    const $set = {};
    // Tax-free POS — always coerce to 0 regardless of what the client sends.
    $set.taxRate = 0;
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
