// lib/services/step_tracking_service.dart
//
// Compatible with flutter_foreground_task ^8.14.0 / ^9.0.0
//
// BREAKING CHANGES vs old code (all fixed here):
//  • onDestroy signature  → Future<void> onDestroy(DateTime, bool isTimeout)
//  • No ReceivePort       → FlutterForegroundTask.addTaskDataCallback()
//  • No iconData / ResourceType / ResourcePrefix / NotificationIconData
//    (removed from AndroidNotificationOptions in v8)
//  • ForegroundTaskOptions uses eventAction, not interval
//  • TaskDataCallback type alias removed → use void Function(Object) directly
//  • addTaskDataCallback / removeTaskDataCallback return void (don't use result)
//  • startStepTaskCallback lives in main.dart — imported from there via callback param

import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';

// ── Message keys sent between isolates ──────────────────────────────────────
const String kMsgStepCount   = 'step_count';
const String kMsgWalkStarted = 'walk_started';
const String kMsgWalkStopped = 'walk_stopped';

// ── Task handler – runs in the background isolate ────────────────────────────
// The @pragma entry-point + startStepTaskCallback() that instantiates this
// class MUST be declared in main.dart (Flutter requirement).
class StepTaskHandler extends TaskHandler {
  StreamSubscription<StepCount>? _stepSub;

  int  _lastHardwareSteps = 0;
  int  _lastCadenceBase   = 0;
  int  _confirmCount      = 0;
  int  _idleCount         = 0;
  bool _walkActive        = false;
  bool _paused            = false;
  int? _walkStartEpoch;
  int  _walkBaseSteps     = 0;

  static const int _cadenceThreshold = 40;
  static const int _confirmWindows   = 3;
  static const int _idleWindows      = 6;
  static const int _maxWalkMinutes   = 90;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _stepSub = Pedometer.stepCountStream.listen(
          (event) {
        _lastHardwareSteps = event.steps;
        FlutterForegroundTask.sendDataToMain({kMsgStepCount: event.steps});
      },
      onError: (_) {},
    );
    _lastCadenceBase = _lastHardwareSteps;
  }

  // Fires every 10 000 ms as set in ForegroundTaskOptions.
  @override
  void onRepeatEvent(DateTime timestamp) {
    if (!_paused) {
      _evaluateCadence();
      _checkMaxDuration();
    }
  }

  // Correct signature for flutter_foreground_task >= 8.14 and 9.x
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _stepSub?.cancel();
  }

  // Receives pause / resume commands from the main isolate.
  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    final cmd = data['cmd'] as String?;
    if (cmd == 'pause') {
      _paused = true;
    } else if (cmd == 'resume') {
      _paused          = false;
      _lastCadenceBase = _lastHardwareSteps;
      _confirmCount    = 0;
      _idleCount       = 0;
    }
  }

  void _evaluateCadence() {
    final delta      = _lastHardwareSteps - _lastCadenceBase;
    _lastCadenceBase = _lastHardwareSteps;
    final cadence    = delta * 6;

    if (cadence >= _cadenceThreshold) {
      _idleCount = 0;
      _confirmCount++;

      if (!_walkActive && _confirmCount >= _confirmWindows) {
        _walkActive     = true;
        _walkStartEpoch = DateTime.now()
            .subtract(Duration(seconds: _confirmWindows * 10))
            .millisecondsSinceEpoch;
        _walkBaseSteps  = _lastHardwareSteps;
        FlutterForegroundTask.sendDataToMain({kMsgWalkStarted: _walkStartEpoch});
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

  void _checkMaxDuration() {
    if (!_walkActive || _walkStartEpoch == null) return;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - _walkStartEpoch!;
    if (elapsedMs >= _maxWalkMinutes * 60 * 1000) _triggerStop();
  }

  void _triggerStop() {
    if (!_walkActive) return;
    final start    = DateTime.fromMillisecondsSinceEpoch(_walkStartEpoch!);
    final duration = DateTime.now().difference(start).inMinutes.clamp(1, 9999);
    final steps    = (_lastHardwareSteps - _walkBaseSteps).clamp(0, 999999);

    FlutterForegroundTask.sendDataToMain({
      kMsgWalkStopped: {
        'steps':           steps,
        'durationMinutes': duration,
        'startEpoch':      _walkStartEpoch,
      },
    });

    _walkActive     = false;
    _walkStartEpoch = null;
    _walkBaseSteps  = 0;
    _confirmCount   = 0;
    _idleCount      = 0;
  }
}

// ── Public API ───────────────────────────────────────────────────────────────
class StepTrackingService {
  StepTrackingService._();

  static bool _initialized = false;

  // FIX: TaskDataCallback was removed from the package.
  // Declare our own alias so the rest of the codebase stays clean.
  // This matches what addTaskDataCallback / removeTaskDataCallback actually accept.
  // ignore: prefer_function_declarations_over_variables

  // Call once in main() before runApp().  Safe to call multiple times.
  static void init() {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId:          'step_tracking',
        channelName:        'Step Tracking',
        channelDescription: 'Tracks your steps in the background',
        // NOTE: iconData / ResourceType / ResourcePrefix were REMOVED in v8.
        // Do not include them — they cause "Undefined name" compile errors.
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound:        false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction:                ForegroundTaskEventAction.repeat(10000),
        autoRunOnBoot:              true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock:              true,
        allowWifiLock:              false,
      ),
    );
  }

  // FIX: startStepTaskCallback is defined in main.dart with @pragma.
  // We accept it as a parameter here so this file has zero dependency on it.
  static Future<void> startService({
    required void Function() taskCallback,
  }) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId:         256,
        notificationTitle: 'FitPulse',
        notificationText:  'Monitoring your steps…',
        callback:          taskCallback,           // ← passed in, not hardcoded
      );
    }
  }

  static Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
  }

  static Future<void> pauseDetection() async {
    FlutterForegroundTask.sendDataToTask({'cmd': 'pause'});
  }

  static Future<void> resumeDetection() async {
    FlutterForegroundTask.sendDataToTask({'cmd': 'resume'});
  }

  // FIX: TaskDataCallback no longer exists in the package.
  // Use the raw function type `void Function(Object)` instead.
  // FIX: addTaskDataCallback / removeTaskDataCallback both return void —
  // never assign or check their return value.
  static void addDataCallback(void Function(Object) callback) {
    FlutterForegroundTask.addTaskDataCallback(callback);   // returns void — OK
  }

  static void removeDataCallback(void Function(Object) callback) {
    FlutterForegroundTask.removeTaskDataCallback(callback); // returns void — OK
  }
}