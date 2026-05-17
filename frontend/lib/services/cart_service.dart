import 'package:flutter/foundation.dart';

import '../models/menu_item.dart';
import '../models/order.dart';

/// Shared cart state. Lives above the POS screen so the AppBar can show
/// a badge count and the cart sheet can be opened from anywhere.
class CartService extends ChangeNotifier {
  final List<CartLine> _items = [];
  String _paymentMethod = 'cash';
  double _discount = 0;

  static const double taxRate = 0.05;

  List<CartLine> get items => List.unmodifiable(_items);
  String get paymentMethod => _paymentMethod;
  double get discount => _discount;

  int get count => _items.fold<int>(0, (sum, l) => sum + l.quantity);
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  double get subtotal => _items.fold<double>(0, (sum, l) => sum + l.lineTotal);
  double get taxableBase {
    final b = subtotal - _discount;
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
    _discount = 0;
    _paymentMethod = 'cash';
    notifyListeners();
  }

  void setDiscount(double v) {
    _discount = v < 0 ? 0 : v;
    notifyListeners();
  }

  void setPaymentMethod(String v) {
    _paymentMethod = v;
    notifyListeners();
  }
}
