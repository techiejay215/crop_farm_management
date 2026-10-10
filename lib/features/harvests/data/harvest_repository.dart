import 'package:cloud_firestore/cloud_firestore.dart';
import 'harvest_model.dart';

class HarvestRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Harvest>> streamHarvests(String farmId) {
    return _db
        .collection('farms')
        .doc(farmId)
        .collection('harvests')
        .orderBy('harvestDate', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Harvest.fromFirestore(d, farmId)).toList());
  }

  Future<String> addHarvest(String farmId, Harvest harvest) async {
    final ref = await _db
        .collection('farms')
        .doc(farmId)
        .collection('harvests')
        .add(harvest.toFirestore());
    return ref.id;
  }

  Future<void> updateHarvest(
      String farmId, String harvestId, Map<String, dynamic> data) async {
    await _db
        .collection('farms')
        .doc(farmId)
        .collection('harvests')
        .doc(harvestId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteHarvest(String farmId, String harvestId) async {
    await _db
        .collection('farms')
        .doc(farmId)
        .collection('harvests')
        .doc(harvestId)
        .delete();
  }
}