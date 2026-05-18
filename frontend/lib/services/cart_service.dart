import 'package:flutter/foundation.dart';

import '../models/menu_item.dart';
import '../models/order.dart';

/// One table's in-progress cart. Held in memory; cleared when the order is
/// charged or held to the server.
class _Cart {
  final List<CartLine> items = [];
  String orderType = 'dine-in';
  String paymentMethod = 'cash';
  String discountType = 'fixed';
  double discountValue = 0;
  String customerName = '';
  String customerPhone = '';
  String customerAddress = '';
  String tableLabel = '';
  String? heldOrderId;
}

/// Maintains one cart per table (keyed by tableId, with '' for "no table").
/// The public API always reflects the **active** cart so existing widgets
/// keep working unchanged — they just see whatever cart belongs to the
/// currently-selected table.
class CartService extends ChangeNotifier {
  final Map<String, _Cart> _carts = {};
  String _activeKey = '';
  double taxRate = 0.05;

  _Cart get _c => _carts.putIfAbsent(_activeKey, () => _Cart());

  // ---------- table selection ----------

  String? get tableId => _activeKey.isEmpty ? null : _activeKey;
  String get tableLabel => _c.tableLabel;

  /// Switch the active cart to a given table. Preserves whatever was being
  /// edited for the table previously, if anything.
  void selectTable({String? id, String label = ''}) {
    final key = id ?? '';
    _activeKey = key;
    final c = _carts.putIfAbsent(key, () => _Cart());
    if (label.isNotEmpty) c.tableLabel = label;
    notifyListeners();
  }

  /// Returns true if the table identified by [id] has any in-memory items
  /// (used by the POS to decide whether to re-fetch the held order or just
  /// show the local cart).
  bool hasLocalItemsFor(String? id) {
    final c = _carts[id ?? ''];
    return c != null && c.items.isNotEmpty;
  }

  /// Active cart's totals etc. become a no-op until a table is reselected.
  void setTable({String? id, String? label}) =>
      selectTable(id: id, label: label ?? '');

  // ---------- active cart proxies ----------

  List<CartLine> get items => List.unmodifiable(_c.items);
  String get orderType => _c.orderType;
  String get paymentMethod => _c.paymentMethod;
  String get discountType => _c.discountType;
  double get discountValue => _c.discountValue;
  String get customerName => _c.customerName;
  String get customerPhone => _c.customerPhone;
  String get customerAddress => _c.customerAddress;
  String? get heldOrderId => _c.heldOrderId;

  int get count => _c.items.fold<int>(0, (sum, l) => sum + l.quantity);
  bool get isEmpty => _c.items.isEmpty;
  bool get isNotEmpty => _c.items.isNotEmpty;

  double get subtotal =>
      _c.items.fold<double>(0, (sum, l) => sum + l.lineTotal);

  double get discount {
    if (_c.discountType == 'percent') {
      final d = subtotal * (_c.discountValue / 100);
      return d > subtotal ? subtotal : d;
    }
    return _c.discountValue > subtotal ? subtotal : _c.discountValue;
  }

  double get taxableBase {
    final b = subtotal - discount;
    return b < 0 ? 0 : b;
  }

  double get tax => taxableBase * taxRate;
  double get total => taxableBase + tax;

  // ---------- mutations on active cart ----------

  void add(MenuItem item) {
    final i = _c.items.indexWhere((l) => l.item.id == item.id);
    if (i >= 0) {
      _c.items[i].quantity += 1;
    } else {
      _c.items.add(CartLine(item: item));
    }
    notifyListeners();
  }

  void increment(CartLine line) {
    line.quantity += 1;
    notifyListeners();
  }

  void decrement(CartLine line) {
    line.quantity -= 1;
    if (line.quantity <= 0) _c.items.remove(line);
    notifyListeners();
  }

  void remove(CartLine line) {
    _c.items.remove(line);
    notifyListeners();
  }

  /// Wipe the active cart entirely AND drop it from the map so the next
  /// selectTable for that key starts fresh. Used after a successful Hold or
  /// Charge — the server is now the source of truth.
  void clear() {
    final key = _activeKey;
    _carts.remove(key);
    notifyListeners();
  }

  void setOrderType(String v) {
    _c.orderType = v;
    notifyListeners();
  }

  void setDiscount({String? type, double? value}) {
    if (type != null) _c.discountType = type;
    if (value != null) _c.discountValue = value < 0 ? 0 : value;
    notifyListeners();
  }

  void setPaymentMethod(String v) {
    _c.paymentMethod = v;
    notifyListeners();
  }

  void setCustomer({String? name, String? phone, String? address}) {
    if (name != null) _c.customerName = name;
    if (phone != null) _c.customerPhone = phone;
    if (address != null) _c.customerAddress = address;
    notifyListeners();
  }

  void setTaxRate(double v) {
    taxRate = v;
    notifyListeners();
  }

  /// Replace the active cart from a held order (resuming a previously held
  /// order from the server).
  void loadFromOrder(OrderSummary o, List<CartLine> lines) {
    _c.items
      ..clear()
      ..addAll(lines);
    _c.orderType = o.orderType;
    _c.discountType = o.discountType ?? 'fixed';
    _c.discountValue = o.discountValue ?? 0;
    _c.customerName = o.customerName ?? '';
    _c.customerPhone = o.customerPhone ?? '';
    _c.customerAddress = '';
    _c.tableLabel = o.tableLabel ?? _c.tableLabel;
    _c.heldOrderId = o.id;
    notifyListeners();
  }

  /// How many tables currently have in-flight (in-memory) carts.
  int get activeTableCount =>
      _carts.values.where((c) => c.items.isNotEmpty).length;
}
