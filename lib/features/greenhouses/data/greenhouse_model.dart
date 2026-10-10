import 'package:cloud_firestore/cloud_firestore.dart';

class Greenhouse {
  final String id;
  final String farmId;
  final String name;        // 'Greenhouse 1'
  final double size;        // sq meters
  final String currentCrop; // 'Tomatoes'
  final int plantCount;

  Greenhouse({
    required this.id,
    required this.farmId,
    required this.name,
    required this.size,
    required this.currentCrop,
    required this.plantCount,
  });

  factory Greenhouse.fromFirestore(DocumentSnapshot doc, String farmId) {
    final d = doc.data() as Map<String, dynamic>;
    return Greenhouse(
      id: doc.id,
      farmId: farmId,
      name: d['name'] ?? '',
      size: (d['size'] ?? 0).toDouble(),
      currentCrop: d['currentCrop'] ?? '',
      plantCount: d['plantCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'size': size,
    'currentCrop': currentCrop,
    'plantCount': plantCount,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}