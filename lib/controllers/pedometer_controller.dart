// lib/controllers/pedometer_controller.dart
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import '../services/step_tracking_service.dart';
import '../main.dart' show startStepTaskCallback;

typedef AutoSaveCallback = void Function({
required DateTime startTime,
required int steps,
required int durationMinutes,
});

class PedometerController extends ChangeNotifier {
  // ── Step counts ──────────────────────────────────────────────────────────────
  int _totalSteps        = 0;
  int _sessionSteps      = 0;
  int _sessionStartSteps = 0;

  // ── Live-session streams ─────────────────────────────────────────────────────
  StreamSubscription<StepCount>?        _manualStepSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  // ── Auto-detect stream (main isolate) ────────────────────────────────────────
  StreamSubscription<StepCount>? _autoDetectStepSubscription;

  // ── Status ───────────────────────────────────────────────────────────────────
  bool    _isTracking = false;
  bool    _isWalking  = false;
  String? _error;

  // ── Auto-walk state ──────────────────────────────────────────────────────────
  bool      _isAutoWalkDetected  = false;
  bool      _autoDetectDismissed = false;
  bool      _autoDetectPaused    = false;
  DateTime? _autoDetectStartTime;
  int       _autoDetectBaseSteps = 0;

  // ── Cadence detection (main isolate) ─────────────────────────────────────────
  DateTime? _lastCadenceCheck;
  int       _lastCadenceBase = 0;
  int       _confirmCount    = 0;
  int       _idleCount       = 0;
  bool      _walkActive      = false;
  int?      _walkStartEpoch;
  int       _walkBaseSteps   = 0;

  // testing ver value
  static const int _cadenceThreshold = 3;
  static const int _confirmWindows   = 2;
  static const int _idleWindows      = 2;
  static const int _maxWalkMinutes   = 1;


  // for real production
  // static const int _cadenceThreshold = 8;
  // static const int _confirmWindows   = 3;   // ~30s to confirm
  // static const int _idleWindows      = 10;  // ~100s before auto-save
  // static const int _maxWalkMinutes   = 90; //  walk 90min → auto-save

  // ── Guard so the background service only starts once per app lifetime ─────────
  bool _serviceStarted = false;

  AutoSaveCallback? onAutoSave;

  // ── Getters ──────────────────────────────────────────────────────────────────
  int     get totalSteps   => _totalSteps;
  int     get sessionSteps => _sessionSteps;
  bool    get isTracking   => _isTracking;
  bool    get isWalking    => _isWalking;
  String? get error        => _error;

  bool get isAutoWalkDetected =>
      _isAutoWalkDetected && !_autoDetectDismissed && !_autoDetectPaused;

  int get autoDetectedSteps => _isAutoWalkDetected
      ? (_totalSteps - _autoDetectBaseSteps).clamp(0, 999999)
      : 0;

  DateTime? get autoDetectStartTime => _autoDetectStartTime;

  // ── Permissions ──────────────────────────────────────────────────────────────
  Future<bool> initialize() async {
    try {
      final status = await Permission.activityRecognition.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        _error = 'Activity recognition permission denied';
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      _error = 'Failed to initialize pedometer: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Background service connection ─────────────────────────────────────────────
  void connectToService() {
    StepTrackingService.removeDataCallback(_onServiceData);
    StepTrackingService.addDataCallback(_onServiceData);
    if (!_autoDetectPaused) {
      StepTrackingService.resumeDetection();
    }
  }

  void _onServiceData(Object data) {
    if (data is! Map) return;

    if (data.containsKey(kMsgStepCount)) {
      _totalSteps = data[kMsgStepCount] as int;
      if (_isTracking) {
        if (_sessionStartSteps == 0) _sessionStartSteps = _totalSteps;
        _sessionSteps = (_totalSteps - _sessionStartSteps).clamp(0, 999999);
      }
      notifyListeners();
      return;
    }
  }

  // ── Main isolate cadence detection ────────────────────────────────────────────
  void _startMainIsolateCadence() {
    _autoDetectStepSubscription?.cancel();
    _lastCadenceCheck = null;
    _lastCadenceBase  = 0;
    _confirmCount     = 0;
    _idleCount        = 0;
    _walkActive       = false;
    _walkStartEpoch   = null;
    _walkBaseSteps    = 0;

    _autoDetectStepSubscription = Pedometer.stepCountStream.listen(
          (event) {
        _totalSteps = event.steps;

        // Update live session steps if tracking
        if (_isTracking) {
          if (_sessionStartSteps == 0) _sessionStartSteps = _totalSteps;
          _sessionSteps = (_totalSteps - _sessionStartSteps).clamp(0, 999999);
        }

        notifyListeners();
        if (!_autoDetectPaused) {
          _evaluateCadence();
        }
      },
      onError: (_) {},
    );
  }

  void _evaluateCadence() {
    final now = DateTime.now();
    _lastCadenceCheck ??= now;

    final elapsedSeconds = now.difference(_lastCadenceCheck!).inSeconds;

    // Only evaluate every 10 seconds
    if (elapsedSeconds < 10) return;

    final delta       = _totalSteps - _lastCadenceBase;
    _lastCadenceBase  = _totalSteps;
    _lastCadenceCheck = now;

    if (delta >= _cadenceThreshold) {
      _idleCount = 0;
      _confirmCount++;

      if (!_walkActive && _confirmCount >= _confirmWindows) {
        _walkActive          = true;
        _walkStartEpoch      = DateTime.now()
            .subtract(Duration(seconds: _confirmWindows * 10))
            .millisecondsSinceEpoch;
        _walkBaseSteps       = _totalSteps;
        _isAutoWalkDetected  = true;
        _autoDetectDismissed = false;
        _autoDetectStartTime = DateTime.fromMillisecondsSinceEpoch(_walkStartEpoch!);
        _autoDetectBaseSteps = _totalSteps;
        notifyListeners();
      }
    } else {
      if (_walkActive) {
        _idleCount++;
        if (_idleCount >= _idleWindows) _triggerStop();
      } else {
        _confirmCount = (_confirmCount - 1).clamp(0, _confirmWindows);
      }
    }
  }

  void _triggerStop() {
    if (!_walkActive) return;
    final start    = DateTime.fromMillisecondsSinceEpoch(_walkStartEpoch!);
    final duration = DateTime.now().difference(start).inMinutes.clamp(1, 9999);
    final steps    = (_totalSteps - _walkBaseSteps).clamp(0, 999999);

    onAutoSave?.call(
      startTime:       start,
      steps:           steps,
      durationMinutes: duration,
    );

    _walkActive     = false;
    _walkStartEpoch = null;
    _walkBaseSteps  = 0;
    _confirmCount   = 0;
    _idleCount      = 0;
    _resetAutoDetectState();
    notifyListeners();
  }

  void _checkMaxDuration() {
    if (!_walkActive || _walkStartEpoch == null) return;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - _walkStartEpoch!;
    if (elapsedMs >= _maxWalkMinutes * 60 * 1000) _triggerStop();
  }

  // ── Manual live-session tracking ──────────────────────────────────────────────
  // Future<void> startTracking() async {
  //   if (_isTracking) return;
  //   try {
  //     _manualStepSubscription = Pedometer.stepCountStream.listen(
  //       _onLiveStepCount,
  //       onError: _onStepCountError,
  //     );
  //     _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
  //       _onPedestrianStatus,
  //       onError: (_) {},
  //     );
  //     _isTracking = true;
  //     _error      = null;
  //     notifyListeners();
  //   } catch (e) {
  //     _error      = 'Failed to start tracking: $e';
  //     _isTracking = false;
  //     notifyListeners();
  //   }
  // }

  Future<void> startTracking() async {
    if (_isTracking) return;
    try {
      // Don't open a new stream — reuse the auto-detect stream
      // Just reset the session baseline
      _sessionStartSteps = _totalSteps;
      _sessionSteps      = 0;
      _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
        _onPedestrianStatus,
        onError: (_) {},
      );
      _isTracking = true;
      _error      = null;
      notifyListeners();
    } catch (e) {
      _error      = 'Failed to start tracking: $e';
      _isTracking = false;
      notifyListeners();
    }
  }

  // void stopTracking() {
  //   _manualStepSubscription?.cancel();
  //   _manualStepSubscription = null;
  //   _pedestrianStatusSubscription?.cancel();
  //   _pedestrianStatusSubscription = null;
  //   _isTracking = false;
  //   notifyListeners();
  // }

  void stopTracking() {
    _pedestrianStatusSubscription?.cancel();
    _pedestrianStatusSubscription = null;
    _isTracking = false;
    notifyListeners();
  }

  void resetSession() {
    _sessionStartSteps = _totalSteps;
    _sessionSteps      = 0;
    notifyListeners();
  }

  // ── Auto-detect public API ────────────────────────────────────────────────────
  Future<void> ensureAutoDetectRunning() async {
    if (_serviceStarted) {
      connectToService();
      return;
    }
    await startAutoDetect();
  }

  Future<void> startAutoDetect() async {
    final ok = await initialize();
    if (!ok) return;
    await StepTrackingService.startService(
      taskCallback: startStepTaskCallback,
    );
    connectToService();
    _autoDetectPaused = false;
    _serviceStarted   = true;
    _startMainIsolateCadence(); // ← cadence now runs in main isolate
  }

  void stopAutoDetect() {
    _autoDetectStepSubscription?.cancel();
    StepTrackingService.removeDataCallback(_onServiceData);
    StepTrackingService.stopService();
    _serviceStarted = false;
    _resetAutoDetectState();
    notifyListeners();
  }

  Future<void> pauseAutoDetect() async {
    if (_autoDetectPaused) return;
    _autoDetectPaused = true;
    StepTrackingService.pauseDetection();
  }

  Future<void> resumeAutoDetect() async {
    _autoDetectPaused = false;
    _lastCadenceCheck = null; // reset so cadence doesn't fire immediately
    _lastCadenceBase  = _totalSteps;
    _confirmCount     = 0;
    _idleCount        = 0;
    StepTrackingService.resumeDetection();
    notifyListeners();
  }

  void dismissAutoDetect() {
    _autoDetectDismissed = true;
    notifyListeners();
  }

  void resetAutoDetect() {
    _walkActive     = false;
    _walkStartEpoch = null;
    _walkBaseSteps  = 0;
    _confirmCount   = 0;
    _idleCount      = 0;
    _resetAutoDetectState();
    notifyListeners();
  }

  void _resetAutoDetectState() {
    _isAutoWalkDetected  = false;
    _autoDetectDismissed = false;
    _autoDetectStartTime = null;
    _autoDetectBaseSteps = 0;
  }

  // ── Debug helper ─────────────────────────────────────────────────────────────
  void debugForceShowBanner() {
    _isAutoWalkDetected  = true;
    _autoDetectDismissed = false;
    _autoDetectPaused    = false;
    _autoDetectStartTime = DateTime.now();
    _autoDetectBaseSteps = _totalSteps;
    notifyListeners();
  }

  // ── Live step callbacks ───────────────────────────────────────────────────────
  void _onLiveStepCount(StepCount event) {
    _totalSteps = event.steps;
    if (_isTracking) {
      if (_sessionStartSteps == 0) _sessionStartSteps = _totalSteps;
      _sessionSteps = (_totalSteps - _sessionStartSteps).clamp(0, 999999);
    }
    notifyListeners();
  }

  void _onStepCountError(dynamic error) {
    _error = 'Step count error: $error';
    notifyListeners();
  }

  void _onPedestrianStatus(PedestrianStatus event) {
    _isWalking = event.status == 'walking';
    notifyListeners();
  }

  Future<int?> getCurrentStepCount() async {
    try {
      final stepCount = await Pedometer.stepCountStream.first;
      return stepCount.steps;
    } catch (e) {
      _error = 'Failed to get step count: $e';
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    _autoDetectStepSubscription?.cancel();
    StepTrackingService.removeDataCallback(_onServiceData);
    super.dispose();
  }
}