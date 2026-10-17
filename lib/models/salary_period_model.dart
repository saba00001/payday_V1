import 'dart:convert';

class SalaryPeriodModel {
  final String id;
  final int year;
  final int month;
  final double dailyWage;
  final DateTime createdAt;

  SalaryPeriodModel({
    required this.id,
    required this.year,
    required this.month,
    required this.dailyWage,
    required this.createdAt,
  });

  factory SalaryPeriodModel.fromMap(Map<String, dynamic> map) {
    return SalaryPeriodModel(
      id: map['id'] as String? ?? '',
      year: map['year'] as int? ?? DateTime.now().year,
      month: map['month'] as int? ?? DateTime.now().month,
      dailyWage: (map['dailyWage'] as num?)?.toDouble() ?? 80.0,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'year': year,
    'month': month,
    'dailyWage': dailyWage,
    'createdAt': createdAt.toIso8601String(),
  };

  static String encodeList(List<SalaryPeriodModel> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<SalaryPeriodModel> decodeList(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('Salary period data is invalid.');
    }
    return decoded.map((item) {
      if (item is! Map<String, dynamic> ||
          item['id'] is! String ||
          (item['id'] as String).isEmpty ||
          item['year'] is! int ||
          item['month'] is! int ||
          (item['month'] as int) < 1 ||
          (item['month'] as int) > 12 ||
          item['dailyWage'] is! num ||
          !(item['dailyWage'] as num).isFinite ||
          (item['dailyWage'] as num) < 0 ||
          DateTime.tryParse(item['createdAt'] as String? ?? '') == null) {
        throw const FormatException('Salary period record is invalid.');
      }
      return SalaryPeriodModel.fromMap(item);
    }).toList();
  }

  SalaryPeriodModel copyWith({
    String? id,
    int? year,
    int? month,
    double? dailyWage,
    DateTime? createdAt,
  }) => SalaryPeriodModel(
    id: id ?? this.id,
    year: year ?? this.year,
    month: month ?? this.month,
    dailyWage: dailyWage ?? this.dailyWage,
    createdAt: createdAt ?? this.createdAt,
  );
}
