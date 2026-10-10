import 'package:cloud_firestore/cloud_firestore.dart';
import 'sale_model.dart';

class SaleRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Sale>> streamSales(String farmId) {
    return _db
        .collection('farms')
        .doc(farmId)
        .collection('sales')
        .orderBy('saleDate', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Sale.fromFirestore(d, farmId)).toList());
  }

  Future<String> addSale(String farmId, Sale sale) async {
    final ref = await _db
        .collection('farms')
        .doc(farmId)
        .collection('sales')
        .add(sale.toFirestore());
    return ref.id;
  }

  Future<void> updateSale(
      String farmId, String saleId, Map<String, dynamic> data) async {
    await _db
        .collection('farms')
        .doc(farmId)
        .collection('sales')
        .doc(saleId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteSale(String farmId, String saleId) async {
    await _db
        .collection('farms')
        .doc(farmId)
        .collection('sales')
        .doc(saleId)
        .delete();
  }
}