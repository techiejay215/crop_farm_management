import 'package:cloud_firestore/cloud_firestore.dart';
import 'crop_model.dart';

class CropRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _db.collection('farms').doc(farmId).collection('crops');

  // ---------------------------------------------------------------------------
  // STREAM — sorted client-side so Firestore doesn't require an index
  // ---------------------------------------------------------------------------
  Stream<List<Crop>> streamCrops(String farmId) {
    return _col(farmId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Crop.fromFirestore(d, farmId))
          .toList();

      // Sort newest first — done in Dart so no index is needed.
      list.sort((a, b) {
        final byName =
            a.cropName.toLowerCase().compareTo(b.cropName.toLowerCase());
        if (byName != 0) return byName;
        return a.id.compareTo(b.id); // stable tie-break
      });

      return list;
    });
  }

  Future<void> addCrop(String farmId, Crop crop) async {
    await _col(farmId).add(crop.toFirestore());
  }

  Future<void> updateCrop(
      String farmId, String cropId, Map<String, dynamic> data) async {
    await _col(farmId).doc(cropId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCrop(String farmId, String cropId) async {
    await _col(farmId).doc(cropId).delete();
  }
}