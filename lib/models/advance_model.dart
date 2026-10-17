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
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('Advance data is invalid.');
    }
    return decoded.map((item) {
      if (item is! Map<String, dynamic> ||
          item['id'] is! String ||
          (item['id'] as String).isEmpty ||
          item['amount'] is! num ||
          !(item['amount'] as num).isFinite ||
          (item['amount'] as num) <= 0 ||
          DateTime.tryParse(item['dateTime'] as String? ?? '') == null ||
          !_optionalString(item['objectId']) ||
          !_optionalString(item['objectName'])) {
        throw const FormatException('Advance record is invalid.');
      }
      return AdvanceModel.fromMap(item);
    }).toList();
  }

  static bool _optionalString(Object? value) =>
      value == null || value is String;
}
