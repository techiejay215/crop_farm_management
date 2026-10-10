import 'package:cloud_firestore/cloud_firestore.dart';
import 'greenhouse_model.dart';

class GreenhouseRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Greenhouse>> streamGreenhouses(String farmId) {
    return _db
        .collection('farms')
        .doc(farmId)
        .collection('greenhouses')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Greenhouse.fromFirestore(d, farmId)).toList());
  }

  Future<void> addGreenhouse(String farmId, Greenhouse gh) async {
    await _db.collection('farms').doc(farmId).collection('greenhouses').add(gh.toFirestore());
  }

  Future<void> updateGreenhouse(String farmId, String id, Map<String, dynamic> data) async {
    await _db.collection('farms').doc(farmId).collection('greenhouses').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGreenhouse(String farmId, String id) async {
    await _db.collection('farms').doc(farmId).collection('greenhouses').doc(id).delete();
  }
}