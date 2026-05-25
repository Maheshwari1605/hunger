import 'package:flutter/foundation.dart';

import '../models/order.dart';
import 'api_client.dart';
import 'local_store.dart';

/// Distinguishes "the network failed" (queue locally) from "the server rejected
/// us" (real error — don't queue).
bool _isLikelyNetworkError(Object e) {
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('ClientException') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection refused') ||
      s.contains('Connection timed out') ||
      s.contains('Network is unreachable');
}

class OrderService extends ChangeNotifier {
  final ApiClient _api;
  final LocalStore _store;

  OrderService(this._api, this._store);

  int get pendingCount => _store.queueCount();

  /// Tries to POST the order. If the network is unreachable, queues it
  /// locally and returns a provisional OrderSummary for the receipt.
  Future<OrderSummary> create({
    required List<CartLine> cart,
    required String paymentMethod,
    String orderType = 'dine-in',
    String discountType = 'fixed',
    double discountValue = 0,
    Map<String, String>? customer,
    String? tableId,
    String? tableLabel,
    bool hold = false,
  }) async {
    final payload = {
      'items': cart.map((c) => c.toApiJson()).toList(),
      'orderType': orderType,
      if (!hold) 'paymentMethod': paymentMethod,
      'discountType': discountType,
      'discountValue': discountValue,
      if (customer != null) 'customer': customer,
      if (tableId != null) 'tableId': tableId,
      if (tableLabel != null && tableLabel.isNotEmpty) 'tableLabel': tableLabel,
      if (hold) 'hold': true,
    };

    try {
      final res = await _api.post('/api/orders', payload);
      return OrderSummary.fromJson(res['order'] as Map<String, dynamic>);
    } catch (e) {
      if (!_isLikelyNetworkError(e)) rethrow;

      // Offline path — compute totals client-side, queue, return provisional.
      final localId = DateTime.now().millisecondsSinceEpoch.toString();
      final subtotal =
          cart.fold<double>(0, (s, c) => s + c.item.price * c.quantity);
      double discount = 0;
      if (discountType == 'percent') {
        discount = subtotal * (discountValue / 100);
      } else {
        discount = discountValue;
      }
      if (discount > subtotal) discount = subtotal;
      final taxableBase = (subtotal - discount).clamp(0, double.infinity);
      // Tax-free POS — no tax in offline totals either.
      const tax = 0.0;
      final total = taxableBase + tax;

      await _store.enqueueOrder({
        'localId': localId,
        'queuedAt': DateTime.now().toIso8601String(),
        'payload': payload,
        'snapshot': cart.map((c) => c.toCacheJson()).toList(),
        'totals': {
          'subtotal': subtotal,
          'tax': tax,
          'discount': discount,
          'total': total,
        },
      });
      notifyListeners();

      return OrderSummary.provisional(
        localId: localId,
        cart: cart,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total.toDouble(),
        paymentMethod: paymentMethod,
        orderType: orderType,
        customerName: customer?['name'],
        customerPhone: customer?['phone'],
      );
    }
  }

  /// Settle a held (paymentStatus='open') order.
  Future<OrderSummary> settle(String orderId, String paymentMethod) async {
    final res = await _api.post('/api/orders/$orderId/settle', {
      'paymentMethod': paymentMethod,
    });
    return OrderSummary.fromJson(res['order'] as Map<String, dynamic>);
  }

  /// Replace the contents of an open order — preserves bill number.
  Future<OrderSummary> updateHeld(
    String orderId, {
    required List<CartLine> cart,
    String orderType = 'dine-in',
    String discountType = 'fixed',
    double discountValue = 0,
    Map<String, String>? customer,
    String? tableId,
    String? tableLabel,
  }) async {
    final res = await _api.put('/api/orders/$orderId', {
      'items': cart.map((c) => c.toApiJson()).toList(),
      'orderType': orderType,
      'discountType': discountType,
      'discountValue': discountValue,
      if (customer != null) 'customer': customer,
      if (tableId != null) 'tableId': tableId,
      if (tableLabel != null && tableLabel.isNotEmpty) 'tableLabel': tableLabel,
    });
    return OrderSummary.fromJson(res['order'] as Map<String, dynamic>);
  }

  Future<OrderSummary> get(String orderId) async {
    final res = await _api.get('/api/orders/$orderId');
    return OrderSummary.fromJson(res['order'] as Map<String, dynamic>);
  }

  Future<List<OrderSummary>> list({
    DateTime? from,
    DateTime? to,
    String? kitchenStatus,
    int limit = 50,
  }) async {
    final res = await _api.get('/api/orders', query: {
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      if (kitchenStatus != null) 'kitchenStatus': kitchenStatus,
      'limit': limit,
    });
    return (res['orders'] as List)
        .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OrderSummary> updateKitchenStatus(String id, String status) async {
    final res = await _api.patch('/api/orders/$id/kitchen', {
      'kitchenStatus': status,
    });
    return OrderSummary.fromJson(res['order'] as Map<String, dynamic>);
  }
}
