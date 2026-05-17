import '../models/order.dart';
import 'api_client.dart';

class OrderService {
  final ApiClient _api;
  OrderService(this._api);

  Future<OrderSummary> create({
    required List<CartLine> cart,
    required String paymentMethod,
    double discount = 0,
    Map<String, String>? customer,
  }) async {
    final res = await _api.post('/api/orders', {
      'items': cart.map((c) => c.toApiJson()).toList(),
      'paymentMethod': paymentMethod,
      'discount': discount,
      if (customer != null) 'customer': customer,
    });
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
