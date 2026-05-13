import "dart:async";
import "dart:math";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:sensors_plus/sensors_plus.dart";
import "package:uuid/uuid.dart";
import "../models/crash_event.dart";
import "location_service.dart";

class CrashMonitor extends ChangeNotifier {
  CrashMonitor();

  static const double _instantFactor = 1.45;
  static const int _sustainSamples = 4;
  static const Duration _armingDelay = Duration(seconds: 4);

  bool _monitoring = false;
  bool _coolingDown = false;
  bool _firing = false;
  double _liveMagnitude = 0;
  double _liveGyroMagnitude = 0;
  double _thresholdMps2 = 22;
  double _gyroThresholdRadS = 10;
  int _cooldownSeconds = 10;
  int _highSamples = 0;
  int _gyroHighSamples = 0;
  DateTime? _cooldownEnds;
  Timer? _cooldownTicker;
  Timer? _armingTicker;
  DateTime? _armingEndsAt;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  final List<CrashEvent> _events = [];
  String? _statusNote;
  final _uuid = const Uuid();

  bool get monitoring => _monitoring;
  bool get coolingDown => _coolingDown;
  double get liveMagnitude => _liveMagnitude;
  double get liveGyroMagnitude => _liveGyroMagnitude;
  double get thresholdMps2 => _thresholdMps2;
  double get gyroThresholdRadS => _gyroThresholdRadS;
  int get cooldownSeconds => _cooldownSeconds;
  List<CrashEvent> get events => List.unmodifiable(_events);
  String? get statusNote => _statusNote;
  Duration? get cooldownRemaining {
    final end = _cooldownEnds;
    if (end == null) return null;
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get isArming {
    final end = _armingEndsAt;
    if (end == null) return false;
    return DateTime.now().isBefore(end);
  }

  Duration? get armingRemaining {
    final end = _armingEndsAt;
    if (end == null) return null;
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  set thresholdMps2(double v) {
    _thresholdMps2 = v.clamp(12, 45);
    notifyListeners();
  }

  set gyroThresholdRadS(double v) {
    _gyroThresholdRadS = v.clamp(4, 25);
    notifyListeners();
  }

  set cooldownSeconds(int v) {
    _cooldownSeconds = v.clamp(30, 300);
    notifyListeners();
  }

  bool _isBlockedForDetection() {
    if (_coolingDown || _firing) return true;
    final armingEnd = _armingEndsAt;
    if (armingEnd != null && DateTime.now().isBefore(armingEnd)) return true;
    return false;
  }

  Future<bool> start() async {
    final locOk = await LocationService.ensureLocationReady();
    if (!locOk) {
      _statusNote =
          "Allow location access";
    } else {
      _statusNote = null;
    }
    _monitoring = true;
    _highSamples = 0;
    _gyroHighSamples = 0;
    _armingEndsAt = DateTime.now().add(_armingDelay);
    _armingTicker?.cancel();
    _armingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_armingEndsAt != null &&
          !DateTime.now().isBefore(_armingEndsAt!)) {
        _armingTicker?.cancel();
        _armingTicker = null;
        _armingEndsAt = null;
      }
      notifyListeners();
    });
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    // _accelSub = userAccelerometerEvents.listen(_onAccel, onError: (_) {
    //   _statusNote = "Accelerometer not worked";
    //   notifyListeners();
    // });
    // _gyroSub = gyroscopeEvents.listen(_onGyro, onError: (_) {
    //   _statusNote = "Gyroscope not worked";
    //   notifyListeners();
    // });
    notifyListeners();
    return true;
  }

  Future<void> stop() async {
    _monitoring = false;
    _armingTicker?.cancel();
    _armingTicker = null;
    _armingEndsAt = null;
    await _accelSub?.cancel();
    _accelSub = null;
    await _gyroSub?.cancel();
    _gyroSub = null;
    _liveMagnitude = 0;
    _liveGyroMagnitude = 0;
    notifyListeners();
  }

  void _onAccel(UserAccelerometerEvent e) {
    if (!_monitoring) return;
    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    _liveMagnitude = mag;
    if (_isBlockedForDetection()) {
      _highSamples = 0;
      notifyListeners();
      return;
    }

    final instant = _thresholdMps2 * _instantFactor;
    if (mag >= instant) {
      unawaited(_trigger(peakAccelMps2: mag, peakGyroRadS: _liveGyroMagnitude));
    } else if (mag >= _thresholdMps2) {
      _highSamples += 1;
      if (_highSamples >= _sustainSamples) {
        unawaited(_trigger(peakAccelMps2: mag, peakGyroRadS: _liveGyroMagnitude));
      }
    } else {
      _highSamples = 0;
    }
    notifyListeners();
  }

  void _onGyro(GyroscopeEvent e) {
    if (!_monitoring) return;
    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    _liveGyroMagnitude = mag;
    if (_isBlockedForDetection()) {
      _gyroHighSamples = 0;
      notifyListeners();
      return;
    }

    final instant = _gyroThresholdRadS * _instantFactor;
    if (mag >= instant) {
      unawaited(_trigger(peakAccelMps2: _liveMagnitude, peakGyroRadS: mag));
    } else if (mag >= _gyroThresholdRadS) {
      _gyroHighSamples += 1;
      if (_gyroHighSamples >= _sustainSamples) {
        unawaited(_trigger(peakAccelMps2: _liveMagnitude, peakGyroRadS: mag));
      }
    } else {
      _gyroHighSamples = 0;
    }
    notifyListeners();
  }

  Future<void> _trigger({
    required double peakAccelMps2,
    required double peakGyroRadS,
  }) async {
    if (_firing) return;
    _firing = true;
    try {
      _highSamples = 0;
      _gyroHighSamples = 0;
      _coolingDown = true;
      _cooldownEnds = DateTime.now().add(Duration(seconds: _cooldownSeconds));
      _cooldownTicker?.cancel();
      _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_cooldownEnds != null &&
            DateTime.now().isAfter(_cooldownEnds!)) {
          _coolingDown = false;
          _cooldownTicker?.cancel();
          _cooldownTicker = null;
        }
        notifyListeners();
      });

      // await HapticFeedback.heavyImpact();

      final id = _uuid.v4();
      final ev = CrashEvent(
        id: id,
        detectedAt: DateTime.now(),
        peakMagnitudeMps2: peakAccelMps2,
        peakGyroRadS: peakGyroRadS,
      );
      _events.insert(0, ev);
      notifyListeners();

      final (pos, err) = await LocationService.captureHighAccuracy();
      final idx = _events.indexWhere((x) => x.id == id);
      if (idx >= 0) {
        _events[idx] = CrashEvent(
          id: ev.id,
          detectedAt: ev.detectedAt,
          peakMagnitudeMps2: ev.peakMagnitudeMps2,
          peakGyroRadS: ev.peakGyroRadS,
          position: pos,
          locationError: err,
        );
      }
      notifyListeners();
    } finally {
      _firing = false;
    }
  }

  void clearEvents() {
    _events.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _armingTicker?.cancel();
    unawaited(_accelSub?.cancel());
    unawaited(_gyroSub?.cancel());
    super.dispose();
  }
}
