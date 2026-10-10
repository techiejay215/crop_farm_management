import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ===========================================================================
// Activity types — string-keyed for Firestore friendliness.
// ===========================================================================
class ActivityTypes {
  static const irrigation = 'irrigation';
  static const fertilization = 'fertilization';
  static const spraying = 'spraying';
  static const weeding = 'weeding';
  static const pruning = 'pruning';
  static const planting = 'planting';
  static const transplanting = 'transplanting';
  static const labour = 'labour';
  static const pestDisease = 'pest_disease';
  static const inputPurchase = 'input_purchase';
  static const harvest = 'harvest';
  static const sale = 'sale';
  static const cropLoss = 'crop_loss';
  static const other = 'other';

  static const all = <String>[
    planting,
    transplanting,
    irrigation,
    fertilization,
    spraying,
    weeding,
    pruning,
    labour,
    pestDisease,
    inputPurchase,
    harvest,
    sale,
    cropLoss,
    other,
  ];

  static String label(String v) {
    switch (v) {
      case irrigation: return 'Irrigation';
      case fertilization: return 'Fertilization';
      case spraying: return 'Spraying';
      case weeding: return 'Weeding';
      case pruning: return 'Pruning';
      case planting: return 'Planting';
      case transplanting: return 'Transplanting';
      case labour: return 'Labour';
      case pestDisease: return 'Pest / Disease';
      case inputPurchase: return 'Input Purchase';
      case harvest: return 'Harvest';
      case sale: return 'Sale / Income';
      case cropLoss: return 'Crop Loss';
      default: return 'Other';
    }
  }

  static IconData icon(String v) {
    switch (v) {
      case irrigation: return Icons.water_drop_outlined;
      case fertilization: return Icons.eco_outlined;
      case spraying: return Icons.science_outlined;
      case weeding: return Icons.grass_outlined;
      case pruning: return Icons.content_cut_outlined;
      case planting: return Icons.spa_outlined;
      case transplanting: return Icons.swap_horiz_outlined;
      case labour: return Icons.groups_outlined;
      case pestDisease: return Icons.bug_report_outlined;
      case inputPurchase: return Icons.shopping_bag_outlined;
      case harvest: return Icons.agriculture_outlined;
      case sale: return Icons.attach_money_outlined;
      case cropLoss: return Icons.warning_amber_outlined;
      default: return Icons.notes_outlined;
    }
  }

  static Color color(String v) {
    switch (v) {
      case irrigation: return const Color(0xFF1E88E5);
      case fertilization: return const Color(0xFF43A047);
      case spraying: return const Color(0xFF00897B);
      case weeding: return const Color(0xFF7CB342);
      case pruning: return const Color(0xFF6D4C41);
      case planting: return const Color(0xFF2E7D32);
      case transplanting: return const Color(0xFF558B2F);
      case labour: return const Color(0xFF7E57C2);
      case pestDisease: return const Color(0xFFC62828);
      case inputPurchase: return const Color(0xFFEF6C00);
      case harvest: return const Color(0xFF6A1B9A);
      case sale: return const Color(0xFF00897B);
      case cropLoss: return const Color(0xFFB71C1C);
      default: return const Color(0xFF546E7A);
    }
  }

  /// Whether the activity type typically carries a cost.
  static bool hasCost(String v) =>
      v == fertilization ||
      v == spraying ||
      v == inputPurchase ||
      v == labour ||
      v == irrigation ||
      v == transplanting ||
      v == planting ||
      v == weeding ||
      v == pruning ||
      v == other;

  /// Whether the activity type carries income.
  static bool hasIncome(String v) => v == sale || v == harvest;

  /// Whether the activity type carries a quantity (kg, litres, etc).
  static bool hasQuantity(String v) =>
      v == irrigation ||
      v == fertilization ||
      v == spraying ||
      v == harvest ||
      v == sale ||
      v == cropLoss ||
      v == inputPurchase;

  /// Expense category that best matches the activity type.
  static String expenseCategory(String v) {
    switch (v) {
      case fertilization: return 'fertilizer';
      case spraying: return 'chemicals';
      case labour: return 'labour';
      case irrigation: return 'irrigation';
      case planting:
      case transplanting: return 'seeds';
      case inputPurchase: return 'other';
      default: return 'other';
    }
  }
}

// ===========================================================================
// Model
// ===========================================================================
class CropActivity {
  final String id;
  final String farmId;
  final String cropId;
  final DateTime? date;
  final String type;
  final String description;
  final double? quantity;
  final String? unit;
  final double? cost;
  final double? income;
  final String? personResponsible;
  final String? notes;
  final String? photoUrl;
  final String? linkedExpenseId;
  final String? linkedSaleId;
  final DateTime? createdAt;

  const CropActivity({
    required this.id,
    required this.farmId,
    required this.cropId,
    this.date,
    required this.type,
    required this.description,
    this.quantity,
    this.unit,
    this.cost,
    this.income,
    this.personResponsible,
    this.notes,
    this.photoUrl,
    this.linkedExpenseId,
    this.linkedSaleId,
    this.createdAt,
  });

  bool get hasCost => (cost ?? 0) > 0;
  bool get hasIncome => (income ?? 0) > 0;
  bool get hasQuantity => (quantity ?? 0) > 0;

  factory CropActivity.fromDoc(
    DocumentSnapshot doc, {
    required String farmId,
    required String cropId,
  }) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CropActivity(
      id: doc.id,
      farmId: farmId,
      cropId: cropId,
      date: (d['date'] as Timestamp?)?.toDate(),
      type: (d['type'] ?? 'other') as String,
      description: (d['description'] ?? '') as String,
      quantity: (d['quantity'] as num?)?.toDouble(),
      unit: d['unit'] as String?,
      cost: (d['cost'] as num?)?.toDouble(),
      income: (d['income'] as num?)?.toDouble(),
      personResponsible: d['personResponsible'] as String?,
      notes: d['notes'] as String?,
      photoUrl: d['photoUrl'] as String?,
      linkedExpenseId: d['linkedExpenseId'] as String?,
      linkedSaleId: d['linkedSaleId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'date': date != null
            ? Timestamp.fromDate(date!)
            : FieldValue.serverTimestamp(),
        'type': type,
        'description': description,
        if (quantity != null) 'quantity': quantity,
        if (unit != null) 'unit': unit,
        if (cost != null) 'cost': cost,
        if (income != null) 'income': income,
        if (personResponsible != null && personResponsible!.isNotEmpty)
          'personResponsible': personResponsible,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (linkedExpenseId != null) 'linkedExpenseId': linkedExpenseId,
        if (linkedSaleId != null) 'linkedSaleId': linkedSaleId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}