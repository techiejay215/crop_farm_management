import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String farmId;
  final String category; // 'seeds', 'fertilizer', etc.
  final String description;
  final double amount;
  final String? location;
  final String? cropName;
  final DateTime? date;
  final String? paymentMethod;

  Expense({
    required this.id,
    required this.farmId,
    required this.category,
    required this.description,
    required this.amount,
    this.location,
    this.cropName,
    this.date,
    this.paymentMethod,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc, String farmId) {
    final d = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      farmId: farmId,
      category: d['category'] ?? 'other',
      description: d['description'] ?? '',
      amount: (d['amount'] ?? 0).toDouble(),
      location: d['location'],
      cropName: d['cropName'],
      date: (d['date'] as Timestamp?)?.toDate(),
      paymentMethod: d['paymentMethod'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'category': category,
        'description': description,
        'amount': amount,
        if (location != null) 'location': location,
        if (cropName != null) 'cropName': cropName,
        'date': date != null
            ? Timestamp.fromDate(date!)
            : FieldValue.serverTimestamp(),
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

// Category metadata — used by the UI for icons + labels
class ExpenseCategory {
  static const List<Map<String, dynamic>> all = [
    {'value': 'seeds', 'label': 'Seeds / Seedlings', 'icon': 'grass'},
    {'value': 'fertilizer', 'label': 'Fertilizer', 'icon': 'eco'},
    {'value': 'chemicals', 'label': 'Chemicals / Pesticides', 'icon': 'science'},
    {'value': 'labour', 'label': 'Labour', 'icon': 'engineering'},
    {'value': 'irrigation', 'label': 'Irrigation / Water', 'icon': 'water_drop'},
    {'value': 'transport', 'label': 'Transport', 'icon': 'local_shipping'},
    {'value': 'rent', 'label': 'Land Rent', 'icon': 'key'},
    {'value': 'maintenance', 'label': 'Greenhouse Maintenance', 'icon': 'build'},
    {'value': 'packaging', 'label': 'Packaging & Harvesting', 'icon': 'inventory_2'},
    {'value': 'other', 'label': 'Other', 'icon': 'more_horiz'},
  ];

  static String labelFor(String value) => all
      .firstWhere((e) => e['value'] == value,
          orElse: () => {'label': 'Other'})['label'];
}