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
    try {
      final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map((e) => SalaryPeriodModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
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
