import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum UserActivityKind {
  reading,
  natalChart,
  compatibility,
}

class ActivityStatsRepository {
  static const boxName = 'activity_stats';
  static const _lastActiveKey = 'last_active_ms';

  Box<int> get _box => Hive.box<int>(boxName);

  ValueListenable<Box<int>> listenable() => _box.listenable();

  Future<void> mark(UserActivityKind kind, {DateTime? at}) async {
    final ts = (at ?? DateTime.now()).toLocal();
    final dayKey = _dayKey(ts);
    final kindKey = _kindKey(kind);
    final monthKey = _monthKey(ts);

    final nextDay = (_box.get(dayKey, defaultValue: 0) ?? 0) + 1;
    final nextKind = (_box.get(kindKey, defaultValue: 0) ?? 0) + 1;
    final nextMonth = (_box.get(monthKey, defaultValue: 0) ?? 0) + 1;
    final nextTotal = (_box.get('events_total', defaultValue: 0) ?? 0) + 1;

    await _box.putAll({
      dayKey: nextDay,
      kindKey: nextKind,
      monthKey: nextMonth,
      'events_total': nextTotal,
      _lastActiveKey: ts.millisecondsSinceEpoch,
    });
  }

  Map<DateTime, int> dailyCounts() {
    final out = <DateTime, int>{};
    for (final entry in _box.toMap().entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || !key.startsWith('day:')) {
        continue;
      }
      final date = _parseDayKey(key);
      if (date != null) {
        out[date] = value;
      }
    }
    return out;
  }

  DateTime? lastActiveAt() {
    final raw = _box.get(_lastActiveKey);
    if (raw == null || raw <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(raw).toLocal();
  }

  int totalEvents() => _box.get('events_total', defaultValue: 0) ?? 0;

  int kindCount(UserActivityKind kind) {
    return _box.get(_kindKey(kind), defaultValue: 0) ?? 0;
  }

  String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'day:$y$m$d';
  }

  String _monthKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    return 'month:$y$m';
  }

  String _kindKey(UserActivityKind kind) {
    return 'kind:${kind.name}';
  }

  DateTime? _parseDayKey(String key) {
    final raw = key.substring(4);
    if (raw.length != 8) {
      return null;
    }
    final year = int.tryParse(raw.substring(0, 4));
    final month = int.tryParse(raw.substring(4, 6));
    final day = int.tryParse(raw.substring(6, 8));
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }
}
