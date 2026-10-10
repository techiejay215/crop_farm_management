import 'package:cloud_firestore/cloud_firestore.dart';
import 'crop_activity_model.dart';

class CropActivityRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(
    String farmId,
    String cropId,
  ) =>
      _db
          .collection('farms')
          .doc(farmId)
          .collection('crops')
          .doc(cropId)
          .collection('activities');

  // -------------------------------------------------------------------------
  // STREAM
  // -------------------------------------------------------------------------
  Stream<List<CropActivity>> streamActivities({
    required String farmId,
    required String cropId,
  }) {
    return _col(farmId, cropId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CropActivity.fromDoc(d, farmId: farmId, cropId: cropId))
            .toList());
  }

  // -------------------------------------------------------------------------
  // CREATE — with auto-linkage to expense/sale
  // -------------------------------------------------------------------------
  Future<String> addActivity({
    required CropActivity activity,
    required String cropName,
    required String farmLocation,
  }) async {
    final col = _col(activity.farmId, activity.cropId);
    final ref = col.doc();

    String? expenseId;
    String? saleId;

    // ---- Sync expense ----
    if (activity.hasCost) {
      final expenseRef = _db
          .collection('farms')
          .doc(activity.farmId)
          .collection('expenses')
          .doc();

      await expenseRef.set({
        'category': ActivityTypes.expenseCategory(activity.type),
        'description': activity.description.isEmpty
            ? ActivityTypes.label(activity.type)
            : activity.description,
        'amount': activity.cost,
        'location': farmLocation,
        'cropName': cropName,
        'date': activity.date != null
            ? Timestamp.fromDate(activity.date!)
            : FieldValue.serverTimestamp(),
        'linkedActivityId': ref.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      expenseId = expenseRef.id;
    }

    // ---- Sync sale ----
    if (activity.hasIncome) {
      final saleRef = _db
          .collection('farms')
          .doc(activity.farmId)
          .collection('sales')
          .doc();

      final qty = activity.quantity ?? 0;
      final amount = activity.income ?? 0;
      final pricePerUnit = qty > 0 ? amount / qty : amount;

      await saleRef.set({
        'cropName': cropName,
        'location': farmLocation,
        'buyer': activity.personResponsible ?? '',
        'quantity': qty,
        'unit': activity.unit ?? 'kg',
        'pricePerUnit': pricePerUnit,
        'totalAmount': amount,
        'status': 'completed',
        'saleDate': activity.date != null
            ? Timestamp.fromDate(activity.date!)
            : FieldValue.serverTimestamp(),
        'linkedActivityId': ref.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      saleId = saleRef.id;
    }

    // ---- Write the activity with the linked ids ----
    final data = activity.toFirestore()
      ..['linkedExpenseId'] = expenseId
      ..['linkedSaleId'] = saleId
      ..['createdAt'] = FieldValue.serverTimestamp();

    await ref.set(data);
    return ref.id;
  }

  // -------------------------------------------------------------------------
  // UPDATE — syncs linked expense/sale too
  // -------------------------------------------------------------------------
  Future<void> updateActivity({
    required CropActivity activity,
    required String cropName,
    required String farmLocation,
  }) async {
    final doc = _col(activity.farmId, activity.cropId).doc(activity.id);

    String? expenseId = activity.linkedExpenseId;
    String? saleId = activity.linkedSaleId;

    // ---- Sync expense ----
    if (activity.hasCost) {
      final expenseRef = expenseId != null
          ? _db.collection('farms').doc(activity.farmId).collection('expenses').doc(expenseId)
          : _db.collection('farms').doc(activity.farmId).collection('expenses').doc();
      await expenseRef.set({
        'category': ActivityTypes.expenseCategory(activity.type),
        'description': activity.description.isEmpty
            ? ActivityTypes.label(activity.type)
            : activity.description,
        'amount': activity.cost,
        'location': farmLocation,
        'cropName': cropName,
        'date': activity.date != null
            ? Timestamp.fromDate(activity.date!)
            : FieldValue.serverTimestamp(),
        'linkedActivityId': activity.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      expenseId = expenseRef.id;
    } else if (expenseId != null) {
      // Cost removed — delete the linked expense
      await _db.collection('farms').doc(activity.farmId).collection('expenses').doc(expenseId).delete();
      expenseId = null;
    }

    // ---- Sync sale ----
    if (activity.hasIncome) {
      final saleRef = saleId != null
          ? _db.collection('farms').doc(activity.farmId).collection('sales').doc(saleId)
          : _db.collection('farms').doc(activity.farmId).collection('sales').doc();
      final qty = activity.quantity ?? 0;
      final amount = activity.income ?? 0;
      final pricePerUnit = qty > 0 ? amount / qty : amount;
      await saleRef.set({
        'cropName': cropName,
        'location': farmLocation,
        'buyer': activity.personResponsible ?? '',
        'quantity': qty,
        'unit': activity.unit ?? 'kg',
        'pricePerUnit': pricePerUnit,
        'totalAmount': amount,
        'status': 'completed',
        'saleDate': activity.date != null
            ? Timestamp.fromDate(activity.date!)
            : FieldValue.serverTimestamp(),
        'linkedActivityId': activity.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      saleId = saleRef.id;
    } else if (saleId != null) {
      await _db.collection('farms').doc(activity.farmId).collection('sales').doc(saleId).delete();
      saleId = null;
    }

    final data = activity.toFirestore()
      ..['linkedExpenseId'] = expenseId
      ..['linkedSaleId'] = saleId;

    await doc.update(data);
  }

  // -------------------------------------------------------------------------
  // DELETE — cascades to linked expense/sale
  // -------------------------------------------------------------------------
  Future<void> deleteActivity({
    required String farmId,
    required String cropId,
    required String activityId,
    String? linkedExpenseId,
    String? linkedSaleId,
  }) async {
    if (linkedExpenseId != null) {
      await _db.collection('farms').doc(farmId).collection('expenses').doc(linkedExpenseId).delete();
    }
    if (linkedSaleId != null) {
      await _db.collection('farms').doc(farmId).collection('sales').doc(linkedSaleId).delete();
    }
    await _col(farmId, cropId).doc(activityId).delete();
  }
}