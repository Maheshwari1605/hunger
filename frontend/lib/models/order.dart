import 'menu_item.dart';

class CartLine {
  final MenuItem item;
  int quantity;
  String notes;

  CartLine({required this.item, this.quantity = 1, this.notes = ''});

  double get lineTotal => item.price * quantity;

  Map<String, dynamic> toApiJson() => {
        'menuItemId': item.id,
        'quantity': quantity,
        'notes': notes,
      };

  Map<String, dynamic> toCacheJson() => {
        'menuItemId': item.id,
        'name': item.name,
        'price': item.price,
        'quantity': quantity,
        'notes': notes,
      };
}

class OrderSummary {
  final String id;
  final String orderNumber;
  final String? billNumber;
  final String orderType;
  final String? tableId;
  final String? tableLabel;
  final String? customerName;
  final String? customerPhone;
  final double subtotal;
  final double total;
  final double taxAmount;
  final double discount;
  final String? discountType;
  final double? discountValue;
  final String paymentMethod;
  final String paymentStatus;
  final String kitchenStatus;
  final String cashierName;
  final DateTime createdAt;
  final List<OrderLine> items;
  final bool pendingSync;

  OrderSummary({
    required this.id,
    required this.orderNumber,
    this.billNumber,
    this.orderType = 'dine-in',
    this.tableId,
    this.tableLabel,
    this.customerName,
    this.customerPhone,
    required this.subtotal,
    required this.total,
    required this.taxAmount,
    required this.discount,
    this.discountType,
    this.discountValue,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.kitchenStatus,
    required this.cashierName,
    required this.createdAt,
    required this.items,
    this.pendingSync = false,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> j) {
    final cust = (j['customer'] as Map?) ?? const {};
    return OrderSummary(
      id: j['_id'] as String,
      orderNumber: (j['orderNumber'] ?? '') as String,
      billNumber: j['billNumber'] as String?,
      orderType: (j['orderType'] ?? 'dine-in') as String,
      tableId: j['tableId'] as String?,
      tableLabel: j['tableLabel'] as String?,
      customerName: cust['name'] as String?,
      customerPhone: cust['phone'] as String?,
      subtotal: (j['subtotal'] as num).toDouble(),
      total: (j['total'] as num).toDouble(),
      taxAmount: (j['taxAmount'] as num).toDouble(),
      discount: (j['discount'] as num?)?.toDouble() ?? 0,
      discountType: j['discountType'] as String?,
      discountValue: (j['discountValue'] as num?)?.toDouble(),
      paymentMethod: (j['paymentMethod'] ?? '') as String,
      paymentStatus: (j['paymentStatus'] ?? 'paid') as String,
      kitchenStatus: (j['kitchenStatus'] ?? 'queued') as String,
      cashierName: (j['cashierName'] ?? '') as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      items: ((j['items'] ?? []) as List)
          .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Build a provisional OrderSummary for an order that's been queued offline.
  /// Used only for displaying the receipt — server will create the real record on sync.
  factory OrderSummary.provisional({
    required String localId,
    required List<CartLine> cart,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required String paymentMethod,
    String orderType = 'dine-in',
    String? customerName,
    String? customerPhone,
  }) {
    return OrderSummary(
      id: localId,
      orderNumber:
          'OFFLINE-${localId.substring(localId.length - 6).toUpperCase()}',
      orderType: orderType,
      customerName: customerName,
      customerPhone: customerPhone,
      subtotal: subtotal,
      total: total,
      taxAmount: tax,
      discount: discount,
      paymentMethod: paymentMethod,
      paymentStatus: 'paid',
      kitchenStatus: 'queued',
      cashierName: '',
      createdAt: DateTime.now(),
      items: cart
          .map((c) => OrderLine(
                name: c.item.name,
                price: c.item.price,
                quantity: c.quantity,
                notes: c.notes,
              ))
          .toList(),
      pendingSync: true,
    );
  }
}

class OrderLine {
  final String name;
  final double price;
  final int quantity;
  final String notes;

  OrderLine({
    required this.name,
    required this.price,
    required this.quantity,
    required this.notes,
  });

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        name: j['name'] as String,
        price: (j['price'] as num).toDouble(),
        quantity: (j['quantity'] as num).toInt(),
        notes: (j['notes'] ?? '') as String,
      );
}
