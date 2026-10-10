import 'package:cloud_firestore/cloud_firestore.dart';

/// A user row for the admin panel (customer or admin).
class AdminUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;      // 'admin' | 'customer'
  final String status;    // 'active' | 'paused'
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final int farmCount;

  AdminUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    this.createdAt,
    this.lastLoginAt,
    this.farmCount = 0,
  });

  bool get isAdmin => role == 'admin';
  bool get isCustomer => role == 'customer';
  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';

  String get initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AdminUser.fromDoc(DocumentSnapshot doc, {int farmCount = 0}) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AdminUser(
      uid: doc.id,
      name: d['name'] ?? 'Unnamed',
      email: d['email'] ?? '',
      phone: d['phone'] ?? '',
      role: d['role'] ?? 'customer',
      status: d['status'] ?? 'active',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (d['lastLoginAt'] as Timestamp?)?.toDate(),
      farmCount: farmCount,
    );
  }

  AdminUser copyWith({int? farmCount}) => AdminUser(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        role: role,
        status: status,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt,
        farmCount: farmCount ?? this.farmCount,
      );
}

/// Aggregate admin statistics.
class AdminStats {
  final int totalUsers;
  final int activeUsers;
  final int pausedUsers;
  final int totalCustomers;
  final int totalFarms;
  final List<AdminUser> recentUsers;

  AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.pausedUsers,
    required this.totalCustomers,
    required this.totalFarms,
    required this.recentUsers,
  });
}