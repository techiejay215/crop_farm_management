import 'package:cloud_firestore/cloud_firestore.dart';
import 'farm_model.dart';
import 'farm_payment_info.dart';

/// Repository for the `farms` collection.
///
/// Multi-tenancy rules:
///  - Admins can read/write every farm.
///  - Customers are scoped to `ownerId == their uid` on every query.
///  - Firestore security rules enforce the same at the database layer.
class FarmRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('farms');

  // ---------------------------------------------------------------------------
  // STREAM — list of farms for the current user
  // ---------------------------------------------------------------------------
  /// Live-updating list of farms.
  ///
  /// - role = 'admin'    → all farms
  /// - role = 'customer' → only farms where `ownerId == userId`
  Stream<List<Farm>> streamFarms({
    required String userId,
    required String role,
  }) {
    Query<Map<String, dynamic>> query = _col;

    if (role != 'admin') {
      query = query.where('ownerId', isEqualTo: userId);
    }

    return query.snapshots().map(
          (snap) => snap.docs
              .map((d) => Farm.fromFirestore(d))
              .toList(growable: false),
        );
  }

  // ---------------------------------------------------------------------------
  // STREAM — a single farm (used by the top bar and edit screen)
  // ---------------------------------------------------------------------------
  /// Live stream of a single farm document.
  ///
  /// The Firestore rules will reject reads if the caller doesn't own the farm
  /// and isn't an admin, so no additional client-side check is needed here.
  Stream<Farm?> watchFarm(String farmId) {
    return _col.doc(farmId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Farm.fromFirestore(snap);
    });
  }

  // ---------------------------------------------------------------------------
  // ONE-SHOT — get a farm once
  // ---------------------------------------------------------------------------
  Future<Farm?> getFarmOnce(String farmId) async {
    final snap = await _col.doc(farmId).get();
    if (!snap.exists) return null;
    return Farm.fromFirestore(snap);
  }

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------
  /// Creates a new farm and returns the generated document ID.
  ///
  /// **Admin-only** in normal workflow — customers cannot register farms.
  /// Firestore rules enforce this: only an admin (or the farm's own owner)
  /// can create a document with a given `ownerId`.
  Future<String> createFarm(Farm farm) async {
    final ref = await _col.add(farm.toFirestore());
    return ref.id;
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------
  /// Partial update — only the provided fields are written.
  ///
  /// `updatedAt` is set automatically. Used both for full edits (edit screen)
  /// and lightweight updates (logo swap from the app bar).
  Future<void> updateFarm(String farmId, Map<String, dynamic> data) async {
    await _col.doc(farmId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Convenience wrapper for updating just the logo URL.
  Future<void> updateFarmLogo(String farmId, String? logoUrl) {
    return updateFarm(farmId, {'logoUrl': logoUrl});
  }

  /// Convenience wrapper for renaming a farm.
  Future<void> updateFarmName(String farmId, String farmName) {
    return updateFarm(farmId, {'farmName': farmName});
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------
  /// Deletes a farm document.
  ///
  /// Note: this does NOT recursively delete subcollections (crops, harvests,
  /// sales, expenses, labour, greenhouses). For a full cascade delete, either
  /// do it client-side in a batched write, or use a Cloud Function.
  Future<void> deleteFarm(String farmId) async {
    await _col.doc(farmId).delete();
  }

  // ---------------------------------------------------------------------------
  // PAYMENT INFO — stored at farms/{farmId}/settings/payment
  // ---------------------------------------------------------------------------
  DocumentReference<Map<String, dynamic>> _paymentDoc(String farmId) =>
      _firestore
          .collection('farms')
          .doc(farmId)
          .collection('settings')
          .doc('payment');

  Stream<FarmPaymentInfo?> watchPaymentInfo(String farmId) {
    return _paymentDoc(farmId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return FarmPaymentInfo.fromDoc(snap);
    });
  }

  Future<FarmPaymentInfo?> getPaymentInfo(String farmId) async {
    final snap = await _paymentDoc(farmId).get();
    if (!snap.exists) return null;
    return FarmPaymentInfo.fromDoc(snap);
  }

  Future<void> savePaymentInfo(String farmId, FarmPaymentInfo info) async {
    await _paymentDoc(farmId).set(info.toFirestore());
  }
}