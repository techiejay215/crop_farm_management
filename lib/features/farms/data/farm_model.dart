import 'package:cloud_firestore/cloud_firestore.dart';

class Farm {
  final String id;
  final String ownerId;
  final String farmName;
  final String type; // 'main' or 'rented'
  final String location;
  final double acreage;
  final String? landlord;
  final double? rentalCost;
  final String? rentalPeriod;
  final String? logoUrl;
  final int cropCount;
  final DateTime? createdAt;

  Farm({
    required this.id,
    required this.ownerId,
    required this.farmName,
    required this.type,
    required this.location,
    required this.acreage,
    this.landlord,
    this.rentalCost,
    this.rentalPeriod,
    this.logoUrl,
    this.cropCount = 0,
    this.createdAt,
  });

  factory Farm.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Farm(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      farmName: data['farmName'] ?? '',
      type: data['type'] ?? 'main',
      location: data['location'] ?? '',
      acreage: (data['acreage'] ?? 0).toDouble(),
      landlord: data['landlord'],
      rentalCost: (data['rentalCost'] ?? 0).toDouble(),
      rentalPeriod: data['rentalPeriod'],
      logoUrl: data['logoUrl'],
      cropCount: data['cropCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'ownerId': ownerId,
    'farmName': farmName,
    'type': type,
    'location': location,
    'acreage': acreage,
    if (landlord != null) 'landlord': landlord,
    if (rentalCost != null) 'rentalCost': rentalCost,
    if (rentalPeriod != null) 'rentalPeriod': rentalPeriod,
    if (logoUrl != null) 'logoUrl': logoUrl,
    'cropCount': cropCount,
    'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}