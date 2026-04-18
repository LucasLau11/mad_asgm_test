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
  // ── Step counts ─────────────────────────────────────────────────────────────
  int _totalSteps        = 0;
  int _sessionSteps      = 0;
  int _sessionStartSteps = 0;

  // ── Live-session streams ────────────────────────────────────────────────────
  StreamSubscription<StepCount>?        _manualStepSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  // ── Status ──────────────────────────────────────────────────────────────────
  bool    _isTracking = false;
  bool    _isWalking  = false;
  String? _error;

  // ── Auto-walk state ─────────────────────────────────────────────────────────
  bool      _isAutoWalkDetected  = false;
  bool      _autoDetectDismissed = false;
  bool      _autoDetectPaused    = false;
  DateTime? _autoDetectStartTime;
  int       _autoDetectBaseSteps = 0;

  // ── Guard so the background service only starts once per app lifetime ────────
  bool _serviceStarted = false;

  AutoSaveCallback? onAutoSave;

  // ── Getters ─────────────────────────────────────────────────────────────────
  int     get totalSteps   => _totalSteps;
  int     get sessionSteps => _sessionSteps;
  bool    get isTracking   => _isTracking;
  bool    get isWalking    => _isWalking;
  String? get error        => _error;

  // Banner is visible only when a walk is active, not dismissed, and not paused
  // (paused means the user is inside a live tracking session).
  bool get isAutoWalkDetected =>
      _isAutoWalkDetected && !_autoDetectDismissed && !_autoDetectPaused;

  int get autoDetectedSteps => _isAutoWalkDetected
      ? (_totalSteps - _autoDetectBaseSteps).clamp(0, 999999)
      : 0;

  DateTime? get autoDetectStartTime => _autoDetectStartTime;

  // ── Permissions ─────────────────────────────────────────────────────────────
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

  // ── Background service connection ────────────────────────────────────────────
  void connectToService() {
    StepTrackingService.removeDataCallback(_onServiceData);
    StepTrackingService.addDataCallback(_onServiceData);
  }

  void _onServiceData(Object data) {
    if (data is! Map) return;

    // Raw step count update
    if (data.containsKey(kMsgStepCount)) {
      _totalSteps = data[kMsgStepCount] as int;
      if (_isTracking) {
        if (_sessionStartSteps == 0) _sessionStartSteps = _totalSteps;
        _sessionSteps = (_totalSteps - _sessionStartSteps).clamp(0, 999999);
      }
      notifyListeners();
      return;
    }

    // Walk started — background service confirmed cadence
    if (data.containsKey(kMsgWalkStarted)) {
      if (_autoDetectPaused) return;
      final epochMs = data[kMsgWalkStarted] as int;
      _isAutoWalkDetected  = true;
      _autoDetectDismissed = false;
      _autoDetectStartTime = DateTime.fromMillisecondsSinceEpoch(epochMs);
      _autoDetectBaseSteps = _totalSteps;
      notifyListeners();
      return;
    }

    // Walk stopped — fire auto-save then clear state
    if (data.containsKey(kMsgWalkStopped)) {
      if (_autoDetectPaused) return;
      final payload    = data[kMsgWalkStopped] as Map;
      final steps      = (payload['steps']           as int).clamp(0, 999999);
      final duration   =  payload['durationMinutes'] as int;
      final startEpoch =  payload['startEpoch']      as int;
      final startTime  = DateTime.fromMillisecondsSinceEpoch(startEpoch);

      onAutoSave?.call(
        startTime:       startTime,
        steps:           steps,
        durationMinutes: duration,
      );

      _resetAutoDetectState();
      notifyListeners();
      return;
    }
  }

  // ── Manual live-session tracking ─────────────────────────────────────────────
  Future<void> startTracking() async {
    if (_isTracking) return;
    try {
      _manualStepSubscription = Pedometer.stepCountStream.listen(
        _onLiveStepCount,
        onError: _onStepCountError,
      );
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

  void stopTracking() {
    _manualStepSubscription?.cancel();
    _manualStepSubscription = null;
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

  // ── Auto-detect public API ───────────────────────────────────────────────────

  /// Idempotent — safe to call every time a widget mounts.
  /// The background service is only started once per app lifetime.
  Future<void> ensureAutoDetectRunning() async {
    if (_serviceStarted) {
      // Service already running — just re-register callback in case
      // the widget was rebuilt or remounted.
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
  }

  void stopAutoDetect() {
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
    if (!_autoDetectPaused) return;
    _autoDetectPaused = false;
    StepTrackingService.resumeDetection();
    notifyListeners();
  }

  void dismissAutoDetect() {
    _autoDetectDismissed = true;
    notifyListeners();
  }

  void resetAutoDetect() {
    _resetAutoDetectState();
    notifyListeners();
  }

  void _resetAutoDetectState() {
    _isAutoWalkDetected  = false;
    _autoDetectDismissed = false;
    _autoDetectStartTime = null;
    _autoDetectBaseSteps = 0;
  }

  // ── Live step callbacks ──────────────────────────────────────────────────────
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
    StepTrackingService.removeDataCallback(_onServiceData);
    super.dispose();
  }
}