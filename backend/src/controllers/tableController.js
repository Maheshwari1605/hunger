const Table = require('../models/Table');
const Order = require('../models/Order');

const DEFAULT_TABLES = ['T1', 'T2', 'T3', 'T4', 'T5', 'T6'];

async function ensureDefaultTables(outletId) {
  const count = await Table.countDocuments({ outletId });
  if (count > 0) return;
  await Table.insertMany(
    DEFAULT_TABLES.map((label) => ({ label, capacity: 4, outletId })),
    { ordered: false }
  ).catch(() => {}); // ignore duplicate-key races
}

// Returns each active table with `occupied` derived from open (held) orders.
exports.list = async (req, res, next) => {
  try {
    await ensureDefaultTables(req.user.outletId);
    const tables = await Table.find({ outletId: req.user.outletId, active: true })
      .sort({ label: 1 })
      .lean();
    const occupiedRows = await Order.aggregate([
      {
        $match: {
          outletId: req.user.outletId,
          paymentStatus: 'open',
          tableId: { $ne: null },
        },
      },
      { $group: { _id: '$tableId', orderId: { $first: '$_id' } } },
    ]);
    const occupiedMap = new Map(
      occupiedRows.map((r) => [String(r._id), String(r.orderId)])
    );
    res.json({
      tables: tables.map((t) => ({
        ...t,
        occupied: occupiedMap.has(String(t._id)),
        openOrderId: occupiedMap.get(String(t._id)) || null,
      })),
    });
  } catch (err) {
    next(err);
  }
};

exports.create = async (req, res, next) => {
  try {
    const { label, capacity } = req.body;
    if (!label) return res.status(400).json({ error: 'label required' });
    const table = await Table.create({
      label: label.trim(),
      capacity: capacity || 4,
      outletId: req.user.outletId,
    });
    res.status(201).json({ table });
  } catch (err) {
    next(err);
  }
};

exports.update = async (req, res, next) => {
  try {
    const table = await Table.findOneAndUpdate(
      { _id: req.params.id, outletId: req.user.outletId },
      { $set: req.body },
      { new: true }
    );
    if (!table) return res.status(404).json({ error: 'Table not found' });
    res.json({ table });
  } catch (err) {
    next(err);
  }
};

exports.remove = async (req, res, next) => {
  try {
    const r = await Table.deleteOne({
      _id: req.params.id,
      outletId: req.user.outletId,
    });
    if (r.deletedCount === 0) return res.status(404).json({ error: 'Table not found' });
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
};
