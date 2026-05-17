const Order = require('../models/Order');
const MenuItem = require('../models/MenuItem');

/**
 * Build an order from cart items. Server re-derives prices from the menu
 * so the client cannot tamper with item pricing.
 */
exports.createOrder = async (req, res, next) => {
  try {
    const { items, paymentMethod, discount = 0, taxRate, customer } = req.body;
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'items required' });
    }
    if (!paymentMethod) {
      return res.status(400).json({ error: 'paymentMethod required' });
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

    const subtotal = orderItems.reduce((s, i) => s + i.price * i.quantity, 0);
    const effectiveTaxRate = typeof taxRate === 'number' ? taxRate : 0.05;
    const taxableBase = Math.max(0, subtotal - discount);
    const taxAmount = +(taxableBase * effectiveTaxRate).toFixed(2);
    const total = +(taxableBase + taxAmount).toFixed(2);

    const order = await Order.create({
      items: orderItems,
      subtotal: +subtotal.toFixed(2),
      discount,
      taxRate: effectiveTaxRate,
      taxAmount,
      total,
      paymentMethod,
      cashierId: req.user._id,
      cashierName: req.user.name,
      outletId: req.user.outletId,
      customer: customer || {},
    });

    // Decrement stock where tracked
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

    res.status(201).json({ order });
  } catch (err) {
    next(err);
  }
};

exports.listOrders = async (req, res, next) => {
  try {
    const { from, to, status, kitchenStatus, limit = 50 } = req.query;
    const filter = {};
    if (from || to) {
      filter.createdAt = {};
      if (from) filter.createdAt.$gte = new Date(from);
      if (to) filter.createdAt.$lte = new Date(to);
    }
    if (status) filter.paymentStatus = status;
    if (kitchenStatus) filter.kitchenStatus = kitchenStatus;

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
