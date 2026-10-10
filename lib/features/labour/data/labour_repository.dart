import 'package:cloud_firestore/cloud_firestore.dart';
import 'labour_model.dart';

class LabourRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Labour>> streamLabour(String farmId) {
    return _db
        .collection('farms')
        .doc(farmId)
        .collection('labour')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Labour.fromFirestore(d, farmId)).toList());
  }

  Future<String> addLabour(String farmId, Labour labour) async {
    final ref = await _db
        .collection('farms')
        .doc(farmId)
        .collection('labour')
        .add(labour.toFirestore());
    return ref.id;
  }

  Future<void> updateLabour(
      String farmId, String labourId, Map<String, dynamic> data) async {
    await _db
        .collection('farms')
        .doc(farmId)
        .collection('labour')
        .doc(labourId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteLabour(String farmId, String labourId) async {
    await _db
        .collection('farms')
        .doc(farmId)
        .collection('labour')
        .doc(labourId)
        .delete();
  }
}