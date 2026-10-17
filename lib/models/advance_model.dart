import 'dart:convert';

class AdvanceModel {
  final String id;
  final double amount;
  final DateTime dateTime;
  final String objectId;
  final String objectName;

  const AdvanceModel({
    required this.id,
    required this.amount,
    required this.dateTime,
    required this.objectId,
    required this.objectName,
  });

  factory AdvanceModel.fromMap(Map<String, dynamic> map) => AdvanceModel(
    id: map['id'] as String? ?? '',
    amount: (map['amount'] as num?)?.toDouble() ?? 0,
    dateTime:
        DateTime.tryParse(map['dateTime'] as String? ?? '') ?? DateTime.now(),
    objectId: map['objectId'] as String? ?? '',
    objectName: map['objectName'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'dateTime': dateTime.toIso8601String(),
    'objectId': objectId,
    'objectName': objectName,
  };

  static String encodeList(List<AdvanceModel> list) =>
      jsonEncode(list.map((advance) => advance.toMap()).toList());

  static List<AdvanceModel> decodeList(String json) {
    try {
      final decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map((item) => AdvanceModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
