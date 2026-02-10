import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

enum EnergyAction {
  reading,
  deepDetails,
  natalChart,
}

extension EnergyActionCost on EnergyAction {
  double get cost {
    return switch (this) {
      EnergyAction.reading => 20,
      EnergyAction.deepDetails => 12,
      EnergyAction.natalChart => 35,
    };
  }
}

class EnergyState {
  const EnergyState({
    required this.value,
    required this.lastUpdatedAt,
  });

  final double value;
  final DateTime lastUpdatedAt;

  double get clampedValue => value.clamp(0, EnergyController.maxEnergy);
  double get progress => clampedValue / EnergyController.maxEnergy;
  int get percent => clampedValue.round();
  bool get isLow => clampedValue <= EnergyController.lowThreshold;
  bool get isNearEmpty => clampedValue <= EnergyController.nearEmptyThreshold;

  Duration get timeToFull {
    final missing = EnergyController.maxEnergy - clampedValue;
    if (missing <= 0) {
      return Duration.zero;
    }
    final seconds = (missing / EnergyController.recoveryPerSecond).ceil();
    return Duration(seconds: seconds);
  }

  EnergyState copyWith({
    double? value,
    DateTime? lastUpdatedAt,
  }) {
    return EnergyState(
      value: value ?? this.value,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

class EnergyController extends StateNotifier<EnergyState> {
  EnergyController(this._box) : super(_initialState(_box)) {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final refreshed = _applyRecovery(state, DateTime.now());
      if ((refreshed.clampedValue - state.clampedValue).abs() >= 0.01) {
        state = refreshed;
      }
    });
  }

  static const double maxEnergy = 100;
  static const double recoveryPerSecond = maxEnergy / 3600;
  static const double lowThreshold = 15;
  static const double nearEmptyThreshold = 6;
  static const String valueStorageKey = 'oracle_energy_value';
  static const String timestampStorageKey = 'oracle_energy_updated_at';

  final Box<String> _box;
  Timer? _ticker;

  static EnergyState _initialState(Box<String> box) {
    final storedValue = double.tryParse(box.get(valueStorageKey) ?? '');
    final storedTimestamp = DateTime.tryParse(
      box.get(timestampStorageKey) ?? '',
    );
    final base = EnergyState(
      value: storedValue ?? maxEnergy,
      lastUpdatedAt: storedTimestamp ?? DateTime.now(),
    );
    return _applyRecovery(base, DateTime.now());
  }

  static EnergyState _applyRecovery(EnergyState source, DateTime now) {
    final elapsedSeconds =
        now.difference(source.lastUpdatedAt).inMilliseconds / 1000;
    if (elapsedSeconds <= 0) {
      return source;
    }
    final recovered = source.clampedValue + elapsedSeconds * recoveryPerSecond;
    final next = recovered.clamp(0, maxEnergy);
    return source.copyWith(
      value: next.toDouble(),
      lastUpdatedAt: now,
    );
  }

  void refresh() {
    state = _applyRecovery(state, DateTime.now());
  }

  bool canAfford(EnergyAction action) {
    refresh();
    return state.clampedValue + 1e-9 >= action.cost;
  }

  Future<bool> spend(EnergyAction action) async {
    final now = DateTime.now();
    final refreshed = _applyRecovery(state, now);
    if (refreshed.clampedValue + 1e-9 < action.cost) {
      state = refreshed;
      return false;
    }
    final next = refreshed.copyWith(
      value:
          (refreshed.clampedValue - action.cost).clamp(0, maxEnergy).toDouble(),
      lastUpdatedAt: now,
    );
    state = next;
    await _persist(next);
    return true;
  }

  Future<void> addEnergy(double amount) async {
    if (amount <= 0) {
      return;
    }
    final now = DateTime.now();
    final refreshed = _applyRecovery(state, now);
    final next = refreshed.copyWith(
      value: (refreshed.clampedValue + amount).clamp(0, maxEnergy).toDouble(),
      lastUpdatedAt: now,
    );
    state = next;
    await _persist(next);
  }

  Future<void> fillToMax() async {
    final now = DateTime.now();
    final next = state.copyWith(value: maxEnergy, lastUpdatedAt: now);
    state = next;
    await _persist(next);
  }

  Future<void> _persist(EnergyState source) async {
    await _box.put(valueStorageKey, source.clampedValue.toStringAsFixed(3));
    await _box.put(timestampStorageKey, source.lastUpdatedAt.toIso8601String());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
