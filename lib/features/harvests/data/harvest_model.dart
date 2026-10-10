import 'package:cloud_firestore/cloud_firestore.dart';

class Harvest {
  final String id;
  final String farmId;
  final String cropName;
  final String location;
  final DateTime? harvestDate;
  final double quantity;
  final String unit;
  final String grade;
  final double wastedQuantity;
  final String? notes;

  Harvest({
    required this.id,
    required this.farmId,
    required this.cropName,
    required this.location,
    this.harvestDate,
    required this.quantity,
    required this.unit,
    required this.grade,
    required this.wastedQuantity,
    this.notes,
  });

  factory Harvest.fromFirestore(DocumentSnapshot doc, String farmId) {
    final d = doc.data() as Map<String, dynamic>;
    return Harvest(
      id: doc.id,
      farmId: farmId,
      cropName: d['cropName'] ?? '',
      location: d['location'] ?? '',
      harvestDate: (d['harvestDate'] as Timestamp?)?.toDate(),
      quantity: (d['quantity'] ?? 0).toDouble(),
      unit: d['unit'] ?? 'kg',
      grade: d['grade'] ?? 'A',
      wastedQuantity: (d['wastedQuantity'] ?? 0).toDouble(),
      notes: d['notes'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'cropName': cropName,
        'location': location,
        'harvestDate': harvestDate != null
            ? Timestamp.fromDate(harvestDate!)
            : FieldValue.serverTimestamp(),
        'quantity': quantity,
        'unit': unit,
        'grade': grade,
        'wastedQuantity': wastedQuantity,
        if (notes != null) 'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}