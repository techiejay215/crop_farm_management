import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_models.dart';

// ============================================================================
// STREAMS & AGGREGATES
// ============================================================================

/// Live stream of all users sorted newest-first.
final allUsersStreamProvider = StreamProvider<List<AdminUser>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => AdminUser.fromDoc(d)).toList());
});

/// Aggregate system stats for the admin dashboard.
final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  final db = FirebaseFirestore.instance;

  final usersSnap = await db.collection('users').get();
  final farmsSnap = await db.collection('farms').get();

  // Count farms per owner
  final farmsByOwner = <String, int>{};
  for (final f in farmsSnap.docs) {
    final owner = (f.data()['ownerId'] ?? '') as String;
    farmsByOwner[owner] = (farmsByOwner[owner] ?? 0) + 1;
  }

  final users = usersSnap.docs
      .map((d) => AdminUser.fromDoc(d, farmCount: farmsByOwner[d.id] ?? 0))
      .toList();

  users.sort((a, b) =>
      (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

  final active = users.where((u) => u.isActive).length;
  final paused = users.where((u) => u.isPaused).length;
  final customers = users.where((u) => u.isCustomer).length;

  return AdminStats(
    totalUsers: users.length,
    activeUsers: active,
    pausedUsers: paused,
    totalCustomers: customers,
    totalFarms: farmsSnap.docs.length,
    recentUsers: users.take(5).toList(),
  );
});

// ============================================================================
// FILTER STATE (for user management screen)
// ============================================================================
enum UserStatusFilter { all, active, paused }

final userStatusFilterProvider =
    StateProvider<UserStatusFilter>((ref) => UserStatusFilter.all);

final userSearchQueryProvider = StateProvider<String>((ref) => '');

// ============================================================================
// ACTIONS
// ============================================================================
class AdminActions {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Marks a customer account as paused. They cannot sign in until resumed.
  Future<void> pauseUser(String uid) async {
    await _db.collection('users').doc(uid).update({
      'status': 'paused',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Resumes a paused customer.
  Future<void> resumeUser(String uid) async {
    await _db.collection('users').doc(uid).update({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently deletes a user document AND all their farms
  /// with their subcollections (crops, harvests, sales, expenses, labour, greenhouses).
  ///
  /// NOTE: This does NOT delete the Firebase Auth account (that requires the
  /// Admin SDK / Cloud Function). Since the Firestore user doc is gone,
  /// the app will refuse to complete login for that uid.
  Future<void> deleteUserAndData(String uid) async {
    // 1. Find all farms owned by this user
    final farms = await _db
        .collection('farms')
        .where('ownerId', isEqualTo: uid)
        .get();

    // 2. Delete each farm's subcollections
    const subcollections = [
      'crops',
      'greenhouses',
      'harvests',
      'sales',
      'expenses',
      'labour',
    ];

    for (final farm in farms.docs) {
      for (final sub in subcollections) {
        final docs = await farm.reference.collection(sub).get();
        for (final d in docs.docs) {
          await d.reference.delete();
        }
      }
      await farm.reference.delete();
    }

    // 3. Delete the user document
    await _db.collection('users').doc(uid).delete();
  }
}

final adminActionsProvider =
    Provider<AdminActions>((ref) => AdminActions());