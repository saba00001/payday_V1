import 'dart:convert';

enum WorkDayStatus { worked, notWorked, scheduled, unmarked }

class WorkDayModel {
  final String id;
  final DateTime date;
  final WorkDayStatus status;
  final String objectId;
  final String objectName;
  final double dailyWage;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? workedAt;

  WorkDayModel({
    required this.id,
    required this.date,
    required this.status,
    this.objectId = '',
    this.objectName = '',
    required this.dailyWage,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
    this.workedAt,
  });

  static WorkDayStatus _statusFromString(String v) {
    switch (v) {
      case 'worked':
        return WorkDayStatus.worked;
      case 'notWorked':
        return WorkDayStatus.notWorked;
      case 'scheduled':
        return WorkDayStatus.scheduled;
      default:
        return WorkDayStatus.unmarked;
    }
  }

  static String _statusToString(WorkDayStatus s) {
    switch (s) {
      case WorkDayStatus.worked:
        return 'worked';
      case WorkDayStatus.notWorked:
        return 'notWorked';
      case WorkDayStatus.scheduled:
        return 'scheduled';
      default:
        return 'unmarked';
    }
  }

  factory WorkDayModel.fromMap(Map<String, dynamic> map) {
    return WorkDayModel(
      id: map['id'] as String? ?? '',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      status: _statusFromString(map['status'] as String? ?? 'unmarked'),
      objectId: map['objectId'] as String? ?? '',
      objectName: map['objectName'] as String? ?? '',
      dailyWage: (map['dailyWage'] as num?)?.toDouble() ?? 80.0,
      note: map['note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      workedAt: DateTime.tryParse(map['workedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'status': _statusToString(status),
    'objectId': objectId,
    'objectName': objectName,
    'dailyWage': dailyWage,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'workedAt': workedAt?.toIso8601String(),
  };

  WorkDayModel copyWith({
    String? id,
    DateTime? date,
    WorkDayStatus? status,
    String? objectId,
    String? objectName,
    double? dailyWage,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? workedAt,
  }) => WorkDayModel(
    id: id ?? this.id,
    date: date ?? this.date,
    status: status ?? this.status,
    objectId: objectId ?? this.objectId,
    objectName: objectName ?? this.objectName,
    dailyWage: dailyWage ?? this.dailyWage,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    workedAt: workedAt ?? this.workedAt,
  );

  bool get isWorked => status == WorkDayStatus.worked;

  static String encodeList(List<WorkDayModel> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<WorkDayModel> decodeList(String json) {
    try {
      final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map((e) => WorkDayModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
