import 'package:cloud_firestore/cloud_firestore.dart';

class Labour {
  final String id;
  final String farmId;
  final String workerName;
  final String task;
  final String? location;
  final double daysWorked;
  final double dailyRate;
  final double totalAmount;
  final double amountPaid;
  final DateTime? date;

  Labour({
    required this.id,
    required this.farmId,
    required this.workerName,
    required this.task,
    this.location,
    required this.daysWorked,
    required this.dailyRate,
    required this.totalAmount,
    required this.amountPaid,
    this.date,
  });

  double get pendingAmount => (totalAmount - amountPaid).clamp(0, double.infinity);

  factory Labour.fromFirestore(DocumentSnapshot doc, String farmId) {
    final d = doc.data() as Map<String, dynamic>;
    return Labour(
      id: doc.id,
      farmId: farmId,
      workerName: d['workerName'] ?? '',
      task: d['task'] ?? '',
      location: d['location'],
      daysWorked: (d['daysWorked'] ?? 0).toDouble(),
      dailyRate: (d['dailyRate'] ?? 0).toDouble(),
      totalAmount: (d['totalAmount'] ?? 0).toDouble(),
      amountPaid: (d['amountPaid'] ?? 0).toDouble(),
      date: (d['date'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'workerName': workerName,
        'task': task,
        if (location != null) 'location': location,
        'daysWorked': daysWorked,
        'dailyRate': dailyRate,
        'totalAmount': totalAmount,
        'amountPaid': amountPaid,
        'date': date != null
            ? Timestamp.fromDate(date!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}