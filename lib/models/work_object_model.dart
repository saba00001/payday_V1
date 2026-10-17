import 'dart:convert';

enum WorkObjectStatus { active, completed }

class WorkObjectModel {
  final String id;
  final String name;
  final String address;
  final String note;
  final WorkObjectStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  WorkObjectModel({
    required this.id,
    required this.name,
    this.address = '',
    this.note = '',
    this.status = WorkObjectStatus.active,
    required this.createdAt,
    this.completedAt,
  });

  static WorkObjectStatus _statusFromString(String v) {
    switch (v) {
      case 'completed':
        return WorkObjectStatus.completed;
      default:
        return WorkObjectStatus.active;
    }
  }

  factory WorkObjectModel.fromMap(Map<String, dynamic> map) {
    return WorkObjectModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      note: map['note'] as String? ?? '',
      status: _statusFromString(map['status'] as String? ?? 'active'),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'note': note,
    'status': status == WorkObjectStatus.completed ? 'completed' : 'active',
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  WorkObjectModel copyWith({
    String? id,
    String? name,
    String? address,
    String? note,
    WorkObjectStatus? status,
    DateTime? createdAt,
    Object? completedAt = _sentinel,
  }) => WorkObjectModel(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address ?? this.address,
    note: note ?? this.note,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt == _sentinel
        ? this.completedAt
        : completedAt as DateTime?,
  );

  static const Object _sentinel = Object();

  static String encodeList(List<WorkObjectModel> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<WorkObjectModel> decodeList(String json) {
    try {
      final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map((e) => WorkObjectModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
