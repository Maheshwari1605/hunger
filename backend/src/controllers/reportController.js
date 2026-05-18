const Order = require('../models/Order');

function dayBounds(d = new Date()) {
  const start = new Date(d);
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);
  return { start, end };
}

function monthBounds(d = new Date()) {
  const start = new Date(d.getFullYear(), d.getMonth(), 1);
  const end = new Date(d.getFullYear(), d.getMonth() + 1, 1);
  return { start, end };
}

const PAID_FILTER = { paymentStatus: { $in: ['paid'] } };

exports.dailySales = async (req, res, next) => {
  try {
    const { date } = req.query;
    const { start, end } = dayBounds(date ? new Date(date) : new Date());

    const summary = await Order.aggregate([
      { $match: { createdAt: { $gte: start, $lt: end }, ...PAID_FILTER } },
      {
        $group: {
          _id: null,
          orders: { $sum: 1 },
          revenue: { $sum: '$total' },
          tax: { $sum: '$taxAmount' },
          discount: { $sum: '$discount' },
        },
      },
    ]);

    const byHour = await Order.aggregate([
      { $match: { createdAt: { $gte: start, $lt: end }, ...PAID_FILTER } },
      {
        $group: {
          _id: { $hour: '$createdAt' },
          orders: { $sum: 1 },
          revenue: { $sum: '$total' },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    res.json({
      date: start.toISOString().slice(0, 10),
      summary: summary[0] || { orders: 0, revenue: 0, tax: 0, discount: 0 },
      byHour,
    });
  } catch (err) {
    next(err);
  }
};

exports.monthlySales = async (req, res, next) => {
  try {
    const { month } = req.query; // YYYY-MM
    const base = month ? new Date(`${month}-01T00:00:00`) : new Date();
    const { start, end } = monthBounds(base);

    const byDay = await Order.aggregate([
      { $match: { createdAt: { $gte: start, $lt: end }, ...PAID_FILTER } },
      {
        $group: {
          _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
          orders: { $sum: 1 },
          revenue: { $sum: '$total' },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    const totals = byDay.reduce(
      (acc, d) => {
        acc.orders += d.orders;
        acc.revenue += d.revenue;
        return acc;
      },
      { orders: 0, revenue: 0 }
    );

    res.json({
      month: start.toISOString().slice(0, 7),
      totals,
      byDay,
    });
  } catch (err) {
    next(err);
  }
};

exports.bestSelling = async (req, res, next) => {
  try {
    const { from, to, limit = 10 } = req.query;
    const match = { ...PAID_FILTER };
    if (from || to) {
      match.createdAt = {};
      if (from) match.createdAt.$gte = new Date(from);
      if (to) match.createdAt.$lte = new Date(to);
    }

    const items = await Order.aggregate([
      { $match: match },
      { $unwind: '$items' },
      {
        $group: {
          _id: '$items.menuItemId',
          name: { $first: '$items.name' },
          quantitySold: { $sum: '$items.quantity' },
          revenue: { $sum: { $multiply: ['$items.price', '$items.quantity'] } },
        },
      },
      { $sort: { quantitySold: -1 } },
      { $limit: Math.min(parseInt(limit, 10) || 10, 100) },
    ]);

    res.json({ items });
  } catch (err) {
    next(err);
  }
};

exports.paymentMixSummary = async (req, res, next) => {
  try {
    const { from, to } = req.query;
    const match = { ...PAID_FILTER };
    if (from || to) {
      match.createdAt = {};
      if (from) match.createdAt.$gte = new Date(from);
      if (to) match.createdAt.$lte = new Date(to);
    }
    const mix = await Order.aggregate([
      { $match: match },
      {
        $group: {
          _id: '$paymentMethod',
          orders: { $sum: 1 },
          revenue: { $sum: '$total' },
        },
      },
      { $sort: { revenue: -1 } },
    ]);
    res.json({ mix });
  } catch (err) {
    next(err);
  }
};

function rangeMatch(req) {
  const { from, to } = req.query;
  const match = { ...PAID_FILTER, outletId: req.user.outletId };
  if (from || to) {
    match.createdAt = {};
    if (from) match.createdAt.$gte = new Date(from);
    if (to) match.createdAt.$lte = new Date(to);
  }
  return match;
}

exports.categorySummary = async (req, res, next) => {
  try {
    const match = rangeMatch(req);
    const rows = await Order.aggregate([
      { $match: match },
      { $unwind: '$items' },
      {
        $lookup: {
          from: 'menuitems',
          localField: 'items.menuItemId',
          foreignField: '_id',
          as: 'mi',
        },
      },
      { $unwind: { path: '$mi', preserveNullAndEmptyArrays: true } },
      {
        $group: {
          _id: { $ifNull: ['$mi.category', 'Uncategorized'] },
          quantity: { $sum: '$items.quantity' },
          revenue: { $sum: { $multiply: ['$items.price', '$items.quantity'] } },
        },
      },
      { $sort: { revenue: -1 } },
    ]);
    res.json({ rows });
  } catch (err) {
    next(err);
  }
};

exports.itemSummary = async (req, res, next) => {
  try {
    const match = rangeMatch(req);
    const rows = await Order.aggregate([
      { $match: match },
      { $unwind: '$items' },
      {
        $group: {
          _id: '$items.menuItemId',
          name: { $first: '$items.name' },
          quantity: { $sum: '$items.quantity' },
          revenue: { $sum: { $multiply: ['$items.price', '$items.quantity'] } },
        },
      },
      { $sort: { quantity: -1 } },
    ]);
    res.json({ rows });
  } catch (err) {
    next(err);
  }
};

exports.orderSummary = async (req, res, next) => {
  try {
    const match = rangeMatch(req);
    const rows = await Order.aggregate([
      { $match: match },
      {
        $group: {
          _id: '$orderType',
          orders: { $sum: 1 },
          revenue: { $sum: '$total' },
          avgTicket: { $avg: '$total' },
        },
      },
      { $sort: { revenue: -1 } },
    ]);
    res.json({ rows });
  } catch (err) {
    next(err);
  }
};

exports.employeeSummary = async (req, res, next) => {
  try {
    const match = rangeMatch(req);
    const rows = await Order.aggregate([
      { $match: match },
      {
        $group: {
          _id: { id: '$cashierId', name: '$cashierName' },
          orders: { $sum: 1 },
          revenue: { $sum: '$total' },
        },
      },
      { $sort: { revenue: -1 } },
    ]);
    res.json({
      rows: rows.map((r) => ({
        cashierId: r._id.id,
        cashierName: r._id.name,
        orders: r.orders,
        revenue: r.revenue,
      })),
    });
  } catch (err) {
    next(err);
  }
};
