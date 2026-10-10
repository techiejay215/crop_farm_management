import 'package:cloud_firestore/cloud_firestore.dart';

class Sale {
  final String id;
  final String farmId;
  final String harvestId;
  final String cropName;
  final String location;
  final String buyer;
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final double totalAmount;
  final String status; // 'completed' | 'pending'
  final DateTime? saleDate;

  Sale({
    required this.id,
    required this.farmId,
    required this.harvestId,
    required this.cropName,
    required this.location,
    required this.buyer,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.status,
    this.saleDate,
  });

  factory Sale.fromFirestore(DocumentSnapshot doc, String farmId) {
    final d = doc.data() as Map<String, dynamic>;
    return Sale(
      id: doc.id,
      farmId: farmId,
      harvestId: d['harvestId'] ?? '',
      cropName: d['cropName'] ?? '',
      location: d['location'] ?? '',
      buyer: d['buyer'] ?? '',
      quantity: (d['quantity'] ?? 0).toDouble(),
      unit: d['unit'] ?? 'kg',
      pricePerUnit: (d['pricePerUnit'] ?? 0).toDouble(),
      totalAmount: (d['totalAmount'] ?? 0).toDouble(),
      status: d['status'] ?? 'completed',
      saleDate: (d['saleDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'harvestId': harvestId,
        'cropName': cropName,
        'location': location,
        'buyer': buyer,
        'quantity': quantity,
        'unit': unit,
        'pricePerUnit': pricePerUnit,
        'totalAmount': totalAmount,
        'status': status,
        'saleDate': saleDate != null
            ? Timestamp.fromDate(saleDate!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}