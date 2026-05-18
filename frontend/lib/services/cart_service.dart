import 'package:flutter/foundation.dart';

import '../models/menu_item.dart';
import '../models/order.dart';

class CartService extends ChangeNotifier {
  final List<CartLine> _items = [];
  String _orderType = 'dine-in';
  String _paymentMethod = 'cash';
  String _discountType = 'fixed'; // 'fixed' or 'percent'
  double _discountValue = 0;
  double taxRate = 0.05; // updated from settings on app start

  String customerName = '';
  String customerPhone = '';
  String customerAddress = '';
  String? tableId;
  String tableLabel = '';

  // When resuming a held order, we keep its id so settle can target it.
  String? heldOrderId;

  List<CartLine> get items => List.unmodifiable(_items);
  String get orderType => _orderType;
  String get paymentMethod => _paymentMethod;
  String get discountType => _discountType;
  double get discountValue => _discountValue;

  int get count => _items.fold<int>(0, (sum, l) => sum + l.quantity);
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  double get subtotal => _items.fold<double>(0, (sum, l) => sum + l.lineTotal);

  double get discount {
    if (_discountType == 'percent') {
      final d = subtotal * (_discountValue / 100);
      return d > subtotal ? subtotal : d;
    }
    return _discountValue > subtotal ? subtotal : _discountValue;
  }

  double get taxableBase {
    final b = subtotal - discount;
    return b < 0 ? 0 : b;
  }

  double get tax => taxableBase * taxRate;
  double get total => taxableBase + tax;

  void add(MenuItem item) {
    final i = _items.indexWhere((l) => l.item.id == item.id);
    if (i >= 0) {
      _items[i].quantity += 1;
    } else {
      _items.add(CartLine(item: item));
    }
    notifyListeners();
  }

  void increment(CartLine line) {
    line.quantity += 1;
    notifyListeners();
  }

  void decrement(CartLine line) {
    line.quantity -= 1;
    if (line.quantity <= 0) _items.remove(line);
    notifyListeners();
  }

  void remove(CartLine line) {
    _items.remove(line);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _discountType = 'fixed';
    _discountValue = 0;
    _paymentMethod = 'cash';
    _orderType = 'dine-in';
    customerName = '';
    customerPhone = '';
    customerAddress = '';
    tableId = null;
    tableLabel = '';
    heldOrderId = null;
    notifyListeners();
  }

  void setOrderType(String v) {
    _orderType = v;
    notifyListeners();
  }

  void setDiscount({String? type, double? value}) {
    if (type != null) _discountType = type;
    if (value != null) _discountValue = value < 0 ? 0 : value;
    notifyListeners();
  }

  void setPaymentMethod(String v) {
    _paymentMethod = v;
    notifyListeners();
  }

  void setCustomer({String? name, String? phone, String? address}) {
    if (name != null) customerName = name;
    if (phone != null) customerPhone = phone;
    if (address != null) customerAddress = address;
    notifyListeners();
  }

  void setTable({String? id, String? label}) {
    tableId = id;
    tableLabel = label ?? '';
    notifyListeners();
  }

  void setTaxRate(double v) {
    taxRate = v;
    notifyListeners();
  }

  /// Replace the entire cart from a saved order (used when resuming a held order).
  void loadFromOrder(OrderSummary o, List<CartLine> lines) {
    _items
      ..clear()
      ..addAll(lines);
    _orderType = 'dine-in';
    _discountType = o.discountType ?? 'fixed';
    _discountValue = o.discountValue ?? 0;
    customerName = o.customerName ?? '';
    customerPhone = o.customerPhone ?? '';
    customerAddress = '';
    tableId = o.tableId;
    tableLabel = o.tableLabel ?? '';
    heldOrderId = o.id;
    notifyListeners();
  }
}
