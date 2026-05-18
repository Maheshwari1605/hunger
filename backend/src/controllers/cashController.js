const CashSession = require('../models/CashSession');
const Order = require('../models/Order');

function sumEntries(entries, type) {
  return entries
    .filter((e) => e.type === type)
    .reduce((s, e) => s + e.amount, 0);
}

async function buildSummary(session) {
  if (!session) return null;
  const cashSales = await Order.aggregate([
    {
      $match: {
        outletId: session.outletId,
        paymentMethod: 'cash',
        paymentStatus: 'paid',
        createdAt: {
          $gte: session.openedAt,
          ...(session.closedAt ? { $lte: session.closedAt } : {}),
        },
      },
    },
    { $group: { _id: null, total: { $sum: '$total' }, count: { $sum: 1 } } },
  ]);
  const sales = cashSales[0]?.total || 0;
  const expense = sumEntries(session.entries, 'expense');
  const withdrawal = sumEntries(session.entries, 'withdrawal');
  const topup = sumEntries(session.entries, 'topup');
  const expected = session.openingBalance + sales + topup - expense - withdrawal;
  return {
    session,
    cashSalesTotal: sales,
    cashSalesCount: cashSales[0]?.count || 0,
    expense,
    withdrawal,
    topup,
    expectedCashInDrawer: +expected.toFixed(2),
  };
}

exports.current = async (req, res, next) => {
  try {
    const session = await CashSession.currentOpen(req.user.outletId);
    if (!session) return res.json({ session: null });
    res.json(await buildSummary(session));
  } catch (err) {
    next(err);
  }
};

exports.open = async (req, res, next) => {
  try {
    const existing = await CashSession.currentOpen(req.user.outletId);
    if (existing) return res.status(409).json({ error: 'A session is already open' });
    const { openingBalance } = req.body;
    if (openingBalance == null || openingBalance < 0) {
      return res.status(400).json({ error: 'openingBalance required' });
    }
    const session = await CashSession.create({
      openingBalance,
      openedById: req.user._id,
      openedByName: req.user.name,
      outletId: req.user.outletId,
    });
    res.status(201).json({ session });
  } catch (err) {
    next(err);
  }
};

exports.close = async (req, res, next) => {
  try {
    const session = await CashSession.currentOpen(req.user.outletId);
    if (!session) return res.status(404).json({ error: 'No open session' });
    const { closingBalance } = req.body;
    if (closingBalance == null || closingBalance < 0) {
      return res.status(400).json({ error: 'closingBalance required' });
    }
    session.closedAt = new Date();
    session.closedById = req.user._id;
    session.closedByName = req.user.name;
    session.closingBalance = closingBalance;
    await session.save();
    res.json(await buildSummary(session));
  } catch (err) {
    next(err);
  }
};

exports.addEntry = async (req, res, next) => {
  try {
    const session = await CashSession.currentOpen(req.user.outletId);
    if (!session) return res.status(404).json({ error: 'No open session' });
    const { type, amount, note } = req.body;
    if (!['expense', 'withdrawal', 'topup'].includes(type)) {
      return res.status(400).json({ error: 'invalid type' });
    }
    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'amount required' });
    }
    session.entries.push({
      type,
      amount,
      note: note || '',
      byId: req.user._id,
      byName: req.user.name,
    });
    await session.save();
    res.status(201).json(await buildSummary(session));
  } catch (err) {
    next(err);
  }
};

exports.history = async (req, res, next) => {
  try {
    const { limit = 20 } = req.query;
    const sessions = await CashSession.find({
      outletId: req.user.outletId,
      closedAt: { $ne: null },
    })
      .sort({ closedAt: -1 })
      .limit(Math.min(parseInt(limit, 10) || 20, 100));
    res.json({ sessions });
  } catch (err) {
    next(err);
  }
};
