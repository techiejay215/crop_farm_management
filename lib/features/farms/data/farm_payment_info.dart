import 'package:cloud_firestore/cloud_firestore.dart';

class FarmPaymentInfo {
  final String bankName;
  final String paybill;
  final String account;
  final String phone;
  final String email;
  final String signature;

  const FarmPaymentInfo({
    this.bankName = '',
    this.paybill = '',
    this.account = '',
    this.phone = '',
    this.email = '',
    this.signature = '',
  });

  bool get isEmpty =>
      bankName.isEmpty &&
      paybill.isEmpty &&
      account.isEmpty &&
      phone.isEmpty &&
      email.isEmpty &&
      signature.isEmpty;

  bool get hasPayment =>
      bankName.isNotEmpty || paybill.isNotEmpty || account.isNotEmpty;

  bool get hasContact => phone.isNotEmpty || email.isNotEmpty;

  factory FarmPaymentInfo.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return FarmPaymentInfo(
      bankName: (d['bankName'] ?? '') as String,
      paybill: (d['paybill'] ?? '') as String,
      account: (d['account'] ?? '') as String,
      phone: (d['phone'] ?? '') as String,
      email: (d['email'] ?? '') as String,
      signature: (d['signature'] ?? '') as String,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'bankName': bankName,
        'paybill': paybill,
        'account': account,
        'phone': phone,
        'email': email,
        'signature': signature,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}