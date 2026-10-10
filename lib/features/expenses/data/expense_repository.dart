import 'package:cloud_firestore/cloud_firestore.dart';
import 'expense_model.dart';

class ExpenseRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Expense>> streamExpenses(String farmId) {
    return _db
        .collection('farms')
        .doc(farmId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Expense.fromFirestore(d, farmId)).toList());
  }

  Future<String> addExpense(String farmId, Expense expense) async {
    final ref = await _db
        .collection('farms')
        .doc(farmId)
        .collection('expenses')
        .add(expense.toFirestore());
    return ref.id;
  }

  Future<void> updateExpense(
      String farmId, String expenseId, Map<String, dynamic> data) async {
    await _db
        .collection('farms')
        .doc(farmId)
        .collection('expenses')
        .doc(expenseId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteExpense(String farmId, String expenseId) async {
    await _db
        .collection('farms')
        .doc(farmId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }
}