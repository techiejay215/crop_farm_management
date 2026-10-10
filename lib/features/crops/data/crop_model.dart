import 'package:cloud_firestore/cloud_firestore.dart';

class Crop {
  final String id;
  final String farmId;
  final String cropName;    // 'Tomatoes'
  final String variety;     // 'Roma'
  final String location;    // 'Greenhouse 1' or 'Field A'
  final double acreage;
  final int plantCount;
  final DateTime? plantingDate;
  final DateTime? expectedHarvest;
  final String stage;       // 'growing', 'harvest_ready', 'harvested'

  Crop({
    required this.id,
    required this.farmId,
    required this.cropName,
    required this.variety,
    required this.location,
    required this.acreage,
    required this.plantCount,
    this.plantingDate,
    this.expectedHarvest,
    required this.stage,
  });

  factory Crop.fromFirestore(DocumentSnapshot doc, String farmId) {
    final d = doc.data() as Map<String, dynamic>;
    return Crop(
      id: doc.id,
      farmId: farmId,
      cropName: d['cropName'] ?? '',
      variety: d['variety'] ?? '',
      location: d['location'] ?? '',
      acreage: (d['acreage'] ?? 0).toDouble(),
      plantCount: d['plantCount'] ?? 0,
      plantingDate: (d['plantingDate'] as Timestamp?)?.toDate(),
      expectedHarvest: (d['expectedHarvest'] as Timestamp?)?.toDate(),
      stage: d['stage'] ?? 'growing',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'cropName': cropName,
    'variety': variety,
    'location': location,
    'acreage': acreage,
    'plantCount': plantCount,
    if (plantingDate != null) 'plantingDate': Timestamp.fromDate(plantingDate!),
    if (expectedHarvest != null) 'expectedHarvest': Timestamp.fromDate(expectedHarvest!),
    'stage': stage,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}