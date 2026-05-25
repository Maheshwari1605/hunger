const Order = require('../models/Order');
const MenuItem = require('../models/MenuItem');
const Customer = require('../models/Customer');
const Settings = require('../models/Settings');

function startOfDay(d = new Date()) {
  const s = new Date(d);
  s.setHours(0, 0, 0, 0);
  return s;
}

// Per-outlet, per-day running bill number.
async function nextBillNumber(outletId) {
  const since = startOfDay();
  const count = await Order.countDocuments({
    outletId,
    createdAt: { $gte: since },
  });
  return `B${String(count + 1).padStart(4, '0')}`;
}

function computeTotals({ items, discountType, discountValue }) {
  // Tax-free POS — taxRate is always 0. We keep the field on the response
  // for backward compatibility with older clients that still read it.
  const subtotal = items.reduce((s, i) => s + i.price * i.quantity, 0);
  let discount = 0;
  if (discountType === 'percent') {
    discount = Math.min(subtotal, subtotal * (Number(discountValue) || 0) / 100);
  } else {
    discount = Math.min(subtotal, Number(discountValue) || 0);
  }
  const taxableBase = Math.max(0, subtotal - discount);
  const total = +taxableBase.toFixed(2);
  return {
    subtotal: +subtotal.toFixed(2),
    discount: +discount.toFixed(2),
    taxAmount: 0,
    total,
  };
}

async function upsertCustomer({ outletId, name, phone, address }) {
  if (!phone || !name) return null;
  return Customer.findOneAndUpdate(
    { outletId, phone: phone.trim() },
    {
      $set: {
        name: name.trim(),
        ...(address ? { address } : {}),
      },
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
}

/**
 * Build/save an order. If `hold` is true, paymentStatus='open' and paymentMethod is blank.
 * Otherwise behaves like a normal sale.
 */
exports.createOrder = async (req, res, next) => {
  try {
    const {
      items,
      orderType = 'dine-in',
      paymentMethod,
      discountType = 'fixed',
      discountValue = 0,
      customer = {},
      tableId,
      tableLabel,
      hold = false,
    } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'items required' });
    }
    if (!hold && !paymentMethod) {
      return res.status(400).json({ error: 'paymentMethod required (or set hold:true)' });
    }

    const ids = items.map((i) => i.menuItemId);
    const menuItems = await MenuItem.find({ _id: { $in: ids } });
    const menuMap = new Map(menuItems.map((m) => [m._id.toString(), m]));

    const orderItems = items.map((cartItem) => {
      const menuItem = menuMap.get(String(cartItem.menuItemId));
      if (!menuItem) {
        const err = new Error(`Menu item not found: ${cartItem.menuItemId}`);
        err.status = 400;
        throw err;
      }
      if (!menuItem.available) {
        const err = new Error(`Item unavailable: ${menuItem.name}`);
        err.status = 400;
        throw err;
      }
      const qty = Math.max(1, parseInt(cartItem.quantity || 1, 10));
      return {
        menuItemId: menuItem._id,
        name: menuItem.name,
        price: menuItem.price,
        quantity: qty,
        notes: cartItem.notes || '',
      };
    });

    // Settings read kept for cafeName/etc. side effects; taxRate is ignored.
    await Settings.getOrCreate(req.user.outletId);
    const totals = computeTotals({
      items: orderItems,
      discountType,
      discountValue,
    });

    const cust = await upsertCustomer({
      outletId: req.user.outletId,
      name: customer.name,
      phone: customer.phone,
      address: customer.address,
    });

    const billNumber = await nextBillNumber(req.user.outletId);

    const order = await Order.create({
      billNumber,
      orderType,
      tableId: tableId || null,
      tableLabel: tableLabel || '',
      customerId: cust ? cust._id : null,
      customer: {
        name: customer.name || (cust ? cust.name : ''),
        phone: customer.phone || (cust ? cust.phone : ''),
        address: customer.address || '',
      },
      items: orderItems,
      ...totals,
      discountType,
      discountValue,
      taxRate: 0,
      paymentMethod: hold ? '' : paymentMethod,
      paymentStatus: hold ? 'open' : 'paid',
      cashierId: req.user._id,
      cashierName: req.user.name,
      outletId: req.user.outletId,
    });

    // Bump customer stats only when actually paid.
    if (cust && !hold) {
      await Customer.updateOne(
        { _id: cust._id },
        {
          $inc: { totalOrders: 1, totalSpent: totals.total },
          $set: { lastOrderAt: new Date() },
        }
      );
    }

    // Decrement tracked stock only on paid orders.
    if (!hold) {
      await Promise.all(
        orderItems
          .filter((i) => menuMap.get(String(i.menuItemId)).stock !== null)
          .map((i) =>
            MenuItem.updateOne(
              { _id: i.menuItemId },
              { $inc: { stock: -i.quantity } }
            )
          )
      );
    }

    res.status(201).json({ order });
  } catch (err) {
    next(err);
  }
};

/**
 * Replace the contents of an open (held) order — items, customer, discount.
 * Bill number is preserved. Server re-derives prices and totals.
 */
exports.updateHeldOrder = async (req, res, next) => {
  try {
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    if (order.paymentStatus !== 'open') {
      return res.status(400).json({ error: 'Only open orders can be updated' });
    }

    const {
      items,
      orderType = order.orderType,
      discountType = order.discountType,
      discountValue = order.discountValue,
      customer = {},
      tableId,
      tableLabel,
    } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'items required' });
    }

    const ids = items.map((i) => i.menuItemId);
    const menuItems = await MenuItem.find({ _id: { $in: ids } });
    const menuMap = new Map(menuItems.map((m) => [m._id.toString(), m]));

    const orderItems = items.map((cartItem) => {
      const menuItem = menuMap.get(String(cartItem.menuItemId));
      if (!menuItem) {
        const err = new Error(`Menu item not found: ${cartItem.menuItemId}`);
        err.status = 400;
        throw err;
      }
      const qty = Math.max(1, parseInt(cartItem.quantity || 1, 10));
      return {
        menuItemId: menuItem._id,
        name: menuItem.name,
        price: menuItem.price,
        quantity: qty,
        notes: cartItem.notes || '',
      };
    });

    const totals = computeTotals({
      items: orderItems,
      discountType,
      discountValue,
    });

    order.items = orderItems;
    order.orderType = orderType;
    if (tableId !== undefined) order.tableId = tableId || null;
    if (tableLabel !== undefined) order.tableLabel = tableLabel || '';
    if (customer && (customer.name || customer.phone)) {
      order.customer = {
        name: customer.name || order.customer?.name || '',
        phone: customer.phone || order.customer?.phone || '',
        address: customer.address || order.customer?.address || '',
      };
    }
    order.discountType = discountType;
    order.discountValue = discountValue;
    order.taxRate = 0;
    order.subtotal = totals.subtotal;
    order.discount = totals.discount;
    order.taxAmount = totals.taxAmount;
    order.total = totals.total;
    await order.save();
    res.json({ order });
  } catch (err) {
    next(err);
  }
};

/** Settle a previously held order (paymentStatus 'open' → 'paid'). */
exports.settleOrder = async (req, res, next) => {
  try {
    const { paymentMethod } = req.body;
    if (!paymentMethod) return res.status(400).json({ error: 'paymentMethod required' });
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    if (order.paymentStatus !== 'open') {
      return res.status(400).json({ error: 'Order is not open' });
    }
    order.paymentMethod = paymentMethod;
    order.paymentStatus = 'paid';
    await order.save();
    // Bump customer stats now that it's paid.
    if (order.customerId) {
      await Customer.updateOne(
        { _id: order.customerId },
        {
          $inc: { totalOrders: 1, totalSpent: order.total },
          $set: { lastOrderAt: new Date() },
        }
      );
    }
    res.json({ order });
  } catch (err) {
    next(err);
  }
};

exports.listOrders = async (req, res, next) => {
  try {
    const { from, to, status, kitchenStatus, orderType, limit = 50 } = req.query;
    const filter = { outletId: req.user.outletId };
    if (from || to) {
      filter.createdAt = {};
      if (from) filter.createdAt.$gte = new Date(from);
      if (to) filter.createdAt.$lte = new Date(to);
    }
    if (status) filter.paymentStatus = status;
    if (kitchenStatus) filter.kitchenStatus = kitchenStatus;
    if (orderType) filter.orderType = orderType;

    const orders = await Order.find(filter)
      .sort({ createdAt: -1 })
      .limit(Math.min(parseInt(limit, 10) || 50, 500));
    res.json({ orders });
  } catch (err) {
    next(err);
  }
};

exports.getOrder = async (req, res, next) => {
  try {
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    res.json({ order });
  } catch (err) {
    next(err);
  }
};

exports.updateKitchenStatus = async (req, res, next) => {
  try {
    const { kitchenStatus } = req.body;
    const allowed = ['queued', 'preparing', 'ready', 'served'];
    if (!allowed.includes(kitchenStatus)) {
      return res.status(400).json({ error: 'Invalid kitchenStatus' });
    }
    const order = await Order.findByIdAndUpdate(
      req.params.id,
      { kitchenStatus },
      { new: true }
    );
    if (!order) return res.status(404).json({ error: 'Order not found' });
    res.json({ order });
  } catch (err) {
    next(err);
  }
};

exports.voidOrder = async (req, res, next) => {
  try {
    const order = await Order.findByIdAndUpdate(
      req.params.id,
      { paymentStatus: 'void' },
      { new: true }
    );
    if (!order) return res.status(404).json({ error: 'Order not found' });
    res.json({ order });
  } catch (err) {
    next(err);
  }
};
