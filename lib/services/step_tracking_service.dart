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

  ///testing ver
  static const int _cadenceThreshold = 3;   // almost any movement counts
  /// need 3+ steps in a 10s window to count as "walking"
  static const int _confirmWindows   = 2;   // 20s to trigger banner
  /// need 2 consecutive passing windows = 20s of walking → banner appears
  static const int _idleWindows      = 2;   // 30s stop → auto-save
  /// need 2 consecutive failing windows = 20s of stopping → auto-saves
  static const int _maxWalkMinutes   = 1;   // force auto-save after 5 min
  /// hard cap: auto-saves after 1 minute regardless

  ///step guide or not i also confuse
  /// 0s          — start walking
  /// 10s         — window 1 passes, confirmCount = 1
  /// 20s         — window 2 passes, confirmCount = 2 → BANNER APPEARS
  /// ...
  /// stop walking
  /// 10s of stop — window 1 fails, idleCount = 1
  /// 20s of stop — window 2 fails, idleCount = 2 → AUTO-SAVES TO TODAY'S LOG

  /// Or if you keep walking:
 /// 60s of walking → _maxWalkMinutes = 1 → AUTO-SAVES TO TODAY'S LOG



  /// for real production
  // static const int _cadenceThreshold = 8;
  // static const int _confirmWindows   = 3;   // ~30s to confirm
  // static const int _idleWindows      = 10;  // ~100s before auto-save
  // static const int _maxWalkMinutes   = 90; //  walk 90min → auto-save

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _lastCadenceCheck = DateTime.now();
    _lastCadenceBase  = 0;

    _stepSub = Pedometer.stepCountStream.listen(
          (event) {
        _lastHardwareSteps = event.steps;
        FlutterForegroundTask.sendDataToMain({kMsgStepCount: event.steps});
        _evaluateCadenceOnStep();
        _checkMaxDuration();
      },
      onError: (error) {
        // Send error to main isolate so we can see it
        FlutterForegroundTask.sendDataToMain({'error': error.toString()});
      },
    );

    // Confirm onStart fired
    FlutterForegroundTask.sendDataToMain({'started': true});
  }
  // Fires every 10 000 ms as set in ForegroundTaskOptions.
  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain({'tick': _lastHardwareSteps});
    if (!_paused) {
      _evaluateCadenceOnStep();
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

  DateTime? _lastCadenceCheck;

  void _evaluateCadenceOnStep() {
    if (_paused) return;

    final now = DateTime.now();
    _lastCadenceCheck ??= now;

    final elapsedSeconds = now.difference(_lastCadenceCheck!).inSeconds;

    // Only evaluate every 10 seconds
    if (elapsedSeconds < 10) return;

    final delta = _lastHardwareSteps - _lastCadenceBase;
    _lastCadenceBase  = _lastHardwareSteps;
    _lastCadenceCheck = now;

    if (delta >= _cadenceThreshold) {
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


// ── Public API ───────
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
        onlyAlertOnce:      true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false, //set to true to see notification of the autpdetect walking in the background
        playSound:        false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot:              true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock:              true,
        allowWifiLock:              false,
      ),
    );
  }

  static Future<void> startService({required void Function() taskCallback}) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      // Restart keeps the handler alive — flush any stale _paused = true
      FlutterForegroundTask.sendDataToTask({'cmd': 'resume'});
    } else {
      await FlutterForegroundTask.startService(
        serviceId:         256,
        notificationTitle: 'FitPulse',
        notificationText:  'Step tracking active',
        callback:          taskCallback,
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