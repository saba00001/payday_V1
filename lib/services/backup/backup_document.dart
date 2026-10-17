import 'dart:convert';

import 'package:crypto/crypto.dart';

final class BackupDocument {
  static const formatName = 'payday-local-backup';
  static const formatVersion = 1;

  final DateTime createdAt;
  final Map<String, Object?> data;

  const BackupDocument({required this.createdAt, required this.data});

  String encode() {
    final payload = <String, Object?>{
      'format': formatName,
      'version': formatVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'data': data,
    };
    return jsonEncode({...payload, 'sha256': _digest(payload)});
  }

  static BackupDocument decode(String contents) {
    dynamic decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException {
      throw const FormatException('Backup ფაილი JSON ფორმატში დაზიანებულია.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != formatName ||
        decoded['version'] != formatVersion ||
        decoded['createdAt'] is! String ||
        decoded['data'] is! Map<String, dynamic> ||
        decoded['sha256'] is! String) {
      throw const FormatException(
        'Backup ფაილის ფორმატი უცნობია ან დაზიანებულია.',
      );
    }
    final createdAt = DateTime.tryParse(decoded['createdAt'] as String);
    if (createdAt == null) {
      throw const FormatException('Backup ფაილის თარიღი არასწორია.');
    }
    final payload = <String, Object?>{
      'format': decoded['format'],
      'version': decoded['version'],
      'createdAt': decoded['createdAt'],
      'data': decoded['data'],
    };
    if (_digest(payload) != decoded['sha256']) {
      throw const FormatException(
        'Backup ფაილის მთლიანობის შემოწმება ვერ გაიარა.',
      );
    }
    final data = Map<String, Object?>.from(decoded['data'] as Map);
    validateData(data);
    return BackupDocument(createdAt: createdAt, data: data);
  }

  static void validateData(Map<String, Object?> data) {
    const requiredKeys = {
      'objects',
      'workDays',
      'transactions',
      'advances',
      'periods',
      'dailyWage',
      'reminderEnabled',
      'reminderHour',
      'reminderMinute',
      'workSchedule',
    };
    if (!data.keys.toSet().containsAll(requiredKeys) ||
        data.keys.toSet().difference(requiredKeys).isNotEmpty) {
      throw const FormatException('Backup ფაილში აუცილებელი მონაცემები აკლია.');
    }
    for (final key in [
      'objects',
      'workDays',
      'transactions',
      'advances',
      'periods',
    ]) {
      final records = data[key];
      if (records is! List || records.any((record) => record is! Map)) {
        throw FormatException('Backup ფაილის „$key“ ჩანაწერები არასწორია.');
      }
      final maps = records.cast<Map>();
      _validateUniqueIds(key, maps);
      for (final record in maps) {
        _validateRecord(key, record);
      }
    }
    if (data['dailyWage'] is! num ||
        !(data['dailyWage'] as num).isFinite ||
        (data['dailyWage'] as num) <= 0 ||
        data['reminderEnabled'] is! bool ||
        data['reminderHour'] is! int ||
        (data['reminderHour'] as int) < 0 ||
        (data['reminderHour'] as int) > 23 ||
        data['reminderMinute'] is! int ||
        (data['reminderMinute'] as int) < 0 ||
        (data['reminderMinute'] as int) > 59 ||
        data['workSchedule'] is! List ||
        (data['workSchedule'] as List).any(
          (day) => day is! int || day < 1 || day > 7,
        ) ||
        (data['workSchedule'] as List).toSet().length !=
            (data['workSchedule'] as List).length) {
      throw const FormatException('Backup ფაილის პარამეტრები არასწორია.');
    }
  }

  static void _validateUniqueIds(String key, List<Map> records) {
    final ids = <String>{};
    for (final record in records) {
      final id = record['id'];
      if (id is! String || id.isEmpty || !ids.add(id)) {
        throw FormatException('Backup ფაილის „$key“ ID-ები არასწორია.');
      }
    }
  }

  static void _validateRecord(String collection, Map record) {
    bool date(String key) =>
        record[key] is String &&
        DateTime.tryParse(record[key] as String) != null;
    bool string(String key, {bool required = false}) =>
        record[key] is String &&
        (!required || (record[key] as String).isNotEmpty);
    final valid = switch (collection) {
      'objects' =>
        string('name', required: true) &&
            string('address') &&
            string('note') &&
            const {'active', 'completed'}.contains(record['status']) &&
            date('createdAt') &&
            (record['completedAt'] == null || date('completedAt')),
      'workDays' =>
        date('date') &&
            const {
              'worked',
              'notWorked',
              'scheduled',
              'unmarked',
            }.contains(record['status']) &&
            record['dailyWage'] is num &&
            (record['dailyWage'] as num).isFinite &&
            (record['dailyWage'] as num) >= 0 &&
            date('createdAt') &&
            date('updatedAt') &&
            (record['workedAt'] == null || date('workedAt')) &&
            string('objectId') &&
            string('objectName') &&
            string('note'),
      'transactions' =>
        record['amount'] is num &&
            (record['amount'] as num).isFinite &&
            (record['amount'] as num) >= 0 &&
            date('dateTime') &&
            string('salaryPeriodId') &&
            string('objectId') &&
            string('objectName') &&
            string('note'),
      'advances' =>
        record['amount'] is num &&
            (record['amount'] as num).isFinite &&
            (record['amount'] as num) > 0 &&
            date('dateTime') &&
            string('objectId') &&
            string('objectName'),
      'periods' =>
        record['year'] is int &&
            (record['year'] as int) >= 1 &&
            record['month'] is int &&
            (record['month'] as int) >= 1 &&
            (record['month'] as int) <= 12 &&
            record['dailyWage'] is num &&
            (record['dailyWage'] as num).isFinite &&
            (record['dailyWage'] as num) >= 0 &&
            date('createdAt'),
      _ => false,
    };
    if (!valid) {
      throw FormatException('Backup ფაილის „$collection“ ჩანაწერი არასწორია.');
    }
  }

  static String _digest(Map<String, Object?> payload) =>
      sha256.convert(utf8.encode(jsonEncode(_sortMap(payload)))).toString();

  static Object? _sortMap(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _sortMap(value[key])};
    }
    if (value is List) return value.map(_sortMap).toList();
    return value;
  }
}
