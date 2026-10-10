import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Customer {
  final String uid;
  final String name;
  final String email;
  final String phone;

  Customer({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory Customer.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Customer(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
    );
  }
}

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'customer')
      .snapshots()
      .map((snap) => snap.docs.map((d) => Customer.fromDoc(d)).toList());
});