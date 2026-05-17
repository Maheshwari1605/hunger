class AppUser {
  final String id;
  final String name;
  final String email;
  final String role; // admin | cashier | kitchen
  final String outletId;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.outletId,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        outletId: (j['outletId'] ?? 'default') as String,
      );

  bool get isAdmin => role == 'admin';
  bool get isCashier => role == 'cashier';
  bool get isKitchen => role == 'kitchen';
}
