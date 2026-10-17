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
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('Payment data is invalid.');
    }
    return decoded.map((item) {
      if (item is! Map<String, dynamic> ||
          item['id'] is! String ||
          (item['id'] as String).isEmpty ||
          item['amount'] is! num ||
          !(item['amount'] as num).isFinite ||
          (item['amount'] as num) < 0 ||
          DateTime.tryParse(item['dateTime'] as String? ?? '') == null ||
          !_optionalString(item['salaryPeriodId']) ||
          !_optionalString(item['objectId']) ||
          !_optionalString(item['objectName']) ||
          !_optionalString(item['note'])) {
        throw const FormatException('Payment record is invalid.');
      }
      return PaymentTransactionModel.fromMap(item);
    }).toList();
  }

  static bool _optionalString(Object? value) =>
      value == null || value is String;
}
