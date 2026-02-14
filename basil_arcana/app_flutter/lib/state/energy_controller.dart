import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

enum EnergyAction {
  reading,
  deepDetails,
  natalChart,
  compatibility,
}

extension EnergyActionCost on EnergyAction {
  double get cost {
    return switch (this) {
      EnergyAction.reading => 20,
      EnergyAction.deepDetails => 12,
      EnergyAction.natalChart => 35,
      EnergyAction.compatibility => 35,
    };
  }
}

class EnergyState {
  const EnergyState({
    required this.value,
    required this.lastUpdatedAt,
    this.unlimitedUntil,
    this.promoCodeActive = false,
  });

  final double value;
  final DateTime lastUpdatedAt;
  final DateTime? unlimitedUntil;
  final bool promoCodeActive;

  bool get isUnlimited {
    final until = unlimitedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  double get clampedValue => value.clamp(0, EnergyController.maxEnergy);
  double get progress =>
      isUnlimited ? 1 : clampedValue / EnergyController.maxEnergy;
  int get percent => isUnlimited ? 100 : clampedValue.round();
  bool get isLow => clampedValue <= EnergyController.lowThreshold;
  bool get isNearEmpty => clampedValue <= EnergyController.nearEmptyThreshold;

  Duration get timeToFull {
    if (isUnlimited) {
      return Duration.zero;
    }
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
    DateTime? unlimitedUntil,
    bool? promoCodeActive,
    bool clearUnlimitedUntil = false,
  }) {
    return EnergyState(
      value: value ?? this.value,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      unlimitedUntil:
          clearUnlimitedUntil ? null : (unlimitedUntil ?? this.unlimitedUntil),
      promoCodeActive: promoCodeActive ?? this.promoCodeActive,
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
  static const double recoveryPerSecond = maxEnergy / 1800;
  static const double lowThreshold = 15;
  static const double nearEmptyThreshold = 6;
  static const String valueStorageKey = 'oracle_energy_value';
  static const String timestampStorageKey = 'oracle_energy_updated_at';
  static const String unlimitedUntilStorageKey =
      'oracle_energy_unlimited_until';
  static const String promoCodeActiveStorageKey = 'oracle_promo_active';
  static const String testPromoCode = 'LUCY100';

  final Box<String> _box;
  Timer? _ticker;

  static EnergyState _initialState(Box<String> box) {
    final storedValue = double.tryParse(box.get(valueStorageKey) ?? '');
    final storedTimestamp = DateTime.tryParse(
      box.get(timestampStorageKey) ?? '',
    );
    final storedUnlimitedUntil = DateTime.tryParse(
      box.get(unlimitedUntilStorageKey) ?? '',
    );
    final promoActive = (box.get(promoCodeActiveStorageKey) ?? '') == '1';
    final base = EnergyState(
      value: storedValue ?? maxEnergy,
      lastUpdatedAt: storedTimestamp ?? DateTime.now(),
      unlimitedUntil: storedUnlimitedUntil,
      promoCodeActive: promoActive,
    );
    return _applyRecovery(base, DateTime.now());
  }

  static EnergyState _applyRecovery(EnergyState source, DateTime now) {
    final unlimitedUntil = source.unlimitedUntil;
    if (unlimitedUntil != null && unlimitedUntil.isAfter(now)) {
      return source.copyWith(
        value: maxEnergy,
        lastUpdatedAt: now,
      );
    }
    final elapsedSeconds =
        now.difference(source.lastUpdatedAt).inMilliseconds / 1000;
    if (elapsedSeconds <= 0) {
      return source.copyWith(
        clearUnlimitedUntil: source.unlimitedUntil != null,
      );
    }
    final recovered = source.clampedValue + elapsedSeconds * recoveryPerSecond;
    final next = recovered.clamp(0, maxEnergy);
    return source.copyWith(
      value: next.toDouble(),
      lastUpdatedAt: now,
      clearUnlimitedUntil: source.unlimitedUntil != null,
    );
  }

  void refresh() {
    state = _applyRecovery(state, DateTime.now());
  }

  bool canAfford(EnergyAction action) {
    refresh();
    if (state.isUnlimited) {
      return true;
    }
    return state.clampedValue + 1e-9 >= action.cost;
  }

  Future<bool> spend(EnergyAction action) async {
    final now = DateTime.now();
    final refreshed = _applyRecovery(state, now);
    if (refreshed.isUnlimited) {
      state = refreshed;
      await _persist(refreshed);
      return true;
    }
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

  Future<void> activateUnlimitedForDays(int days) async {
    if (days <= 0) {
      return;
    }
    final now = DateTime.now();
    final next = state.copyWith(
      value: maxEnergy,
      lastUpdatedAt: now,
      unlimitedUntil: now.add(Duration(days: days)),
      promoCodeActive: false,
    );
    state = next;
    await _persist(next);
  }

  Future<void> activateUnlimitedForWeek() async {
    await activateUnlimitedForDays(7);
  }

  Future<void> activateUnlimitedForMonth() async {
    await activateUnlimitedForDays(30);
  }

  Future<void> activateUnlimitedForYear() async {
    await activateUnlimitedForDays(365);
  }

  Future<bool> applyPromoCode(String rawCode) async {
    final normalized = rawCode.trim().toUpperCase();
    if (normalized != testPromoCode) {
      return false;
    }
    final now = DateTime.now();
    final next = state.copyWith(
      value: maxEnergy,
      lastUpdatedAt: now,
      unlimitedUntil: now.add(const Duration(days: 365)),
      promoCodeActive: true,
    );
    state = next;
    await _persist(next);
    return true;
  }

  Future<void> clearPromoCodeAccess() async {
    final now = DateTime.now();
    final next = state.copyWith(
      value: maxEnergy,
      lastUpdatedAt: now,
      clearUnlimitedUntil: true,
      promoCodeActive: false,
    );
    state = next;
    await _persist(next);
  }

  Future<void> _persist(EnergyState source) async {
    await _box.put(valueStorageKey, source.clampedValue.toStringAsFixed(3));
    await _box.put(timestampStorageKey, source.lastUpdatedAt.toIso8601String());
    final until = source.unlimitedUntil;
    if (until != null && until.isAfter(DateTime.now())) {
      await _box.put(unlimitedUntilStorageKey, until.toIso8601String());
    } else {
      await _box.delete(unlimitedUntilStorageKey);
    }
    await _box.put(
      promoCodeActiveStorageKey,
      source.promoCodeActive ? '1' : '0',
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
