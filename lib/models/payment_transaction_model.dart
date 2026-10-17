import 'dart:convert';

class PaymentTransactionModel {
  final String id;
  final double amount;
  final DateTime dateTime;
  final String salaryPeriodId;
  final String objectId;
  final String objectName;
  final String note;

  PaymentTransactionModel({
    required this.id,
    required this.amount,
    required this.dateTime,
    this.salaryPeriodId = '',
    this.objectId = '',
    this.objectName = '',
    this.note = '',
  });

  factory PaymentTransactionModel.fromMap(Map<String, dynamic> map) {
    return PaymentTransactionModel(
      id: map['id'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      dateTime:
          DateTime.tryParse(map['dateTime'] as String? ?? '') ?? DateTime.now(),
      salaryPeriodId: map['salaryPeriodId'] as String? ?? '',
      objectId: map['objectId'] as String? ?? '',
      objectName: map['objectName'] as String? ?? '',
      note: map['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'dateTime': dateTime.toIso8601String(),
    'salaryPeriodId': salaryPeriodId,
    'objectId': objectId,
    'objectName': objectName,
    'note': note,
  };

  PaymentTransactionModel copyWith({
    String? id,
    double? amount,
    DateTime? dateTime,
    String? salaryPeriodId,
    String? objectId,
    String? objectName,
    String? note,
  }) => PaymentTransactionModel(
    id: id ?? this.id,
    amount: amount ?? this.amount,
    dateTime: dateTime ?? this.dateTime,
    salaryPeriodId: salaryPeriodId ?? this.salaryPeriodId,
    objectId: objectId ?? this.objectId,
    objectName: objectName ?? this.objectName,
    note: note ?? this.note,
  );

  static String encodeList(List<PaymentTransactionModel> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<PaymentTransactionModel> decodeList(String json) {
    try {
      final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map(
            (e) => PaymentTransactionModel.fromMap(e as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }
}
