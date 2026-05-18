const Customer = require('../models/Customer');

exports.list = async (req, res, next) => {
  try {
    const { q, limit = 50 } = req.query;
    const filter = { outletId: req.user.outletId };
    if (q) {
      filter.$or = [
        { name: new RegExp(q, 'i') },
        { phone: new RegExp(q, 'i') },
      ];
    }
    const customers = await Customer.find(filter)
      .sort({ lastOrderAt: -1, createdAt: -1 })
      .limit(Math.min(parseInt(limit, 10) || 50, 500));
    res.json({ customers });
  } catch (err) {
    next(err);
  }
};

exports.lookupByPhone = async (req, res, next) => {
  try {
    const { phone } = req.query;
    if (!phone) return res.status(400).json({ error: 'phone required' });
    const customer = await Customer.findOne({
      outletId: req.user.outletId,
      phone: phone.trim(),
    });
    if (!customer) return res.status(404).json({ error: 'Not found' });
    res.json({ customer });
  } catch (err) {
    next(err);
  }
};

exports.create = async (req, res, next) => {
  try {
    const { name, phone, email, address, notes } = req.body;
    if (!name || !phone) return res.status(400).json({ error: 'name and phone required' });
    const customer = await Customer.findOneAndUpdate(
      { outletId: req.user.outletId, phone: phone.trim() },
      {
        $set: { name: name.trim(), email, address, notes },
        $setOnInsert: { outletId: req.user.outletId },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
    res.status(201).json({ customer });
  } catch (err) {
    next(err);
  }
};

exports.update = async (req, res, next) => {
  try {
    const customer = await Customer.findOneAndUpdate(
      { _id: req.params.id, outletId: req.user.outletId },
      { $set: req.body },
      { new: true }
    );
    if (!customer) return res.status(404).json({ error: 'Customer not found' });
    res.json({ customer });
  } catch (err) {
    next(err);
  }
};

exports.remove = async (req, res, next) => {
  try {
    const r = await Customer.deleteOne({
      _id: req.params.id,
      outletId: req.user.outletId,
    });
    if (r.deletedCount === 0) return res.status(404).json({ error: 'Customer not found' });
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
};
