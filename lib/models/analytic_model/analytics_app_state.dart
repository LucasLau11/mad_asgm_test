import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_goal_model.dart';
import '../../controllers/analytics_controller.dart';
import '../exercise_model/exercise_model.dart';
import '../../services/database/heart_rate_database_service.dart' as shared_db;

class AnalyticsAppState extends ChangeNotifier {

  String _userKey(String key) => 'u${_currentUserId}_$key';

  static const _keyDarkMode        = 'analytics_darkMode';
  static const _keyUsername        = 'analytics_username';
  static const _keyGoals           = 'analytics_goals';
  static const _keyNotifications   = 'analytics_notifications';
  static const _keyWorkoutReminder = 'analytics_workoutReminder';
  static const _keyMeasurementUnit = 'analytics_measurementUnit';
  static const _keyGpsTracking     = 'analytics_gpsTracking';

  static const _keyAutoDetect      = 'analytics_autoDetectWorkout';
  static const _keyWeight          = 'analytics_weight';
  static const _keyHeight          = 'analytics_height';
  static const _keyGender          = 'analytics_gender';

  // ── Current logged-in user id (0 = nobody logged in) ────────────────────
  int get _currentUserId {
    try { return shared_db.DatabaseService.currentUserId; } catch (_) { return 0; }
  }

  // ── Shared controller instance ───────────────────────────────────────────
  final AnalyticsController analyticsController = AnalyticsController();

  // ── Loading state ─────────────────────────────────────────────────────────
  bool _analyticsLoading = false;
  bool get analyticsLoading => _analyticsLoading;

  // ── Dark mode ─────────────────────────────────────────────────────────────
  bool _darkMode = false;
  bool get darkMode => _darkMode;
  void setDarkMode(bool value) {
    _darkMode = value;
    notifyListeners();
    _prefs?.setBool(_userKey(_keyDarkMode), value);
  }

  // ── Username ──────────────────────────────────────────────────────────────
  // Seeded from DB on login. User can change it to a display alias via
  // Personal Settings — this saves to prefs but does NOT touch the login DB.
  String _username = '';
  String get username => _username;
  void setUsername(String value) {
    _username = value.trim();
    notifyListeners();
    _prefs?.setString(_userKey(_keyUsername), _username);
  }

  // ── Email — read-only, sourced from the DB user record ───────────────────
  String _email = '';
  String get email => _email;

  // ── Settings toggles ──────────────────────────────────────────────────────
  bool _notifications = true;
  bool get notifications => _notifications;
  void setNotifications(bool value) {
    _notifications = value;
    notifyListeners();
    _prefs?.setBool(_userKey(_keyNotifications), value);
  }

  bool _workoutReminder = true;
  bool get workoutReminder => _workoutReminder;
  void setWorkoutReminder(bool value) {
    _workoutReminder = value;
    notifyListeners();
    _prefs?.setBool(_userKey(_keyWorkoutReminder), value);
  }

  // ── Measurement unit ──────────────────────────────────────────────────────
  String _measurementUnit = 'Metric';
  String get measurementUnit => _measurementUnit;
  bool get isMetric => _measurementUnit == 'Metric';


  void setMeasurementUnit(String value) {
    if (value == _measurementUnit) return;
    _measurementUnit = value;
    _weight = defaultWeight;
    _height = defaultHeight;
    _prefs?.setString(_userKey(_keyMeasurementUnit), value);
    _prefs?.setString(_userKey(_keyWeight), _weight);
    _prefs?.setString(_userKey(_keyHeight), _height);
    notifyListeners();
  }

  List<String> get weightOptions => isMetric
      ? List.generate(91, (i) => '${i + 30} kg')
      : [
    '100 lbs', '110 lbs', '120 lbs', '130 lbs', '140 lbs', '150 lbs',
    '155 lbs', '160 lbs', '165 lbs', '170 lbs', '175 lbs', '180 lbs',
    '185 lbs', '190 lbs', '195 lbs', '200 lbs', '210 lbs', '220 lbs',
    '230 lbs', '240 lbs', '250 lbs', '260 lbs',
  ];

  List<String> get heightOptions => isMetric
      ? List.generate(51, (i) => '${i + 140} cm')
      : [
    '4\'6"', '4\'7"', '4\'8"', '4\'9"', '4\'10"', '4\'11"',
    '5\'0"', '5\'1"', '5\'2"', '5\'3"', '5\'4"', '5\'5"',
    '5\'6"', '5\'7"', '5\'8"', '5\'9"', '5\'10"', '5\'11"',
    '6\'0"', '6\'1"', '6\'2"', '6\'3"', '6\'4"', '6\'5"',
  ];

  String get defaultWeight => isMetric ? '75 kg' : '165 lbs';
  String get defaultHeight => isMetric ? '170 cm' : '5\'7"';

  String displayGoalType(String storedGoalType) {
    const metricToImperial = {
      'Km Ran': 'Miles Ran',
      'Weight Lost (kg)': 'Weight Lost (lbs)',
    };
    const imperialToMetric = {
      'Miles Ran': 'Km Ran',
      'Weight Lost (lbs)': 'Weight Lost (kg)',
    };
    if (isMetric && imperialToMetric.containsKey(storedGoalType)) {
      return '${imperialToMetric[storedGoalType]!} ⚠';
    }
    if (!isMetric && metricToImperial.containsKey(storedGoalType)) {
      return '${metricToImperial[storedGoalType]!} ⚠';
    }
    return storedGoalType;
  }

  // ── Personal settings ─────────────────────────────────────────────────────
  bool _gpsTracking = true;
  bool get gpsTracking => _gpsTracking;
  void setGpsTracking(bool value) {
    _gpsTracking = value;
    notifyListeners();
    _prefs?.setBool(_userKey(_keyGpsTracking), value);
  }

  bool _autoDetectWorkout = true;
  bool get autoDetectWorkout => _autoDetectWorkout;
  void setAutoDetectWorkout(bool value) {
    _autoDetectWorkout = value;
    notifyListeners();
    _prefs?.setBool(_userKey(_keyAutoDetect), value);
  }

  String _weight = '75 kg';
  String get weight => _weight;
  void setWeight(String value) {
    _weight = value;
    notifyListeners();
    _prefs?.setString(_userKey(_keyWeight), value);
  }

  String _height = '170 cm';
  String get height => _height;
  void setHeight(String value) {
    _height = value;
    notifyListeners();
    _prefs?.setString(_userKey(_keyHeight), value);
  }

  String _gender = 'Male';
  String get gender => _gender;
  void setGender(String value) {
    _gender = value;
    notifyListeners();
    _prefs?.setString(_userKey(_keyGender), value);
  }

  // ── Goals ──────────────────────────────────────────────────────────────────
  final List<GoalModel> _goals = [];
  List<GoalModel> get goals => List.unmodifiable(_goals);

  void addGoal(GoalModel goal) {
    _goals.add(goal);
    notifyListeners();
    _saveGoals();
  }

  void removeGoal(String id) {
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
    _saveGoals();
  }

  void updateGoal(GoalModel updated) {
    final index = _goals.indexWhere((g) => g.id == updated.id);
    if (index != -1) {
      _goals[index] = updated;
      notifyListeners();
      _saveGoals();
    }
  }

  void _saveGoals() {

    final encoded = jsonEncode(_goals.map((g) => g.toJson()).toList());
    _prefs?.setString(_userKey(_keyGoals), encoded);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LOGIN HOOK
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> onUserLoggedIn() async {
    final dbUser = shared_db.DatabaseService.currentUser;

    // Email always comes from the DB — not editable here
    _email = dbUser?.email ?? '';

    // Username: use their saved display alias if they set one,
    // otherwise fall back to their actual login username from the DB.
    final saved = _prefs?.getString(_userKey(_keyUsername)) ?? '';
    _username = saved.isNotEmpty ? saved : (dbUser?.username ?? '');

    _darkMode          = _prefs?.getBool(_userKey(_keyDarkMode))          ?? false;
    _notifications     = _prefs?.getBool(_userKey(_keyNotifications))     ?? true;
    _workoutReminder   = _prefs?.getBool(_userKey(_keyWorkoutReminder))   ?? true;
    _measurementUnit   = _prefs?.getString(_userKey(_keyMeasurementUnit)) ?? 'Metric';
    _gpsTracking       = _prefs?.getBool(_userKey(_keyGpsTracking))       ?? true;
    _autoDetectWorkout = _prefs?.getBool(_userKey(_keyAutoDetect))        ?? true;
    _gender            = _prefs?.getString(_userKey(_keyGender))          ?? 'Male';

    _weight = _prefs?.getString(_userKey(_keyWeight))
        ?? (_measurementUnit == 'Metric' ? '75 kg' : '165 lbs');
    _height = _prefs?.getString(_userKey(_keyHeight))
        ?? (_measurementUnit == 'Metric' ? '170 cm' : '5\'7"');

    _goals.clear();
    final goalsJson = _prefs?.getString(_userKey(_keyGoals));
    if (goalsJson != null) {
      final List decoded = jsonDecode(goalsJson);
      _goals.addAll(decoded.map((e) => GoalModel.fromJson(e)));
    }

    await Future.wait([
      analyticsController.loadModel(),
      analyticsController.loadData(_currentUserId),
    ]);

    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LOGOUT HOOK
  // ══════════════════════════════════════════════════════════════════════════
  void onUserLoggedOut() {
    _username          = '';
    _email             = '';
    _darkMode          = false;
    _notifications     = true;
    _workoutReminder   = true;
    _measurementUnit   = 'Metric';
    _gpsTracking       = true;
    _autoDetectWorkout = true;
    _weight            = '75 kg';
    _height            = '170 cm';
    _gender            = 'Male';
    _goals.clear();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ANALYTICS DATA REFRESH
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> refreshAnalytics() async {
    _analyticsLoading = true;
    notifyListeners();
    await analyticsController.loadData(_currentUserId);
    _analyticsLoading = false;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GOAL SYNC FROM EXERCISE
  // ══════════════════════════════════════════════════════════════════════════
  void syncGoalsFromExercise(Exercise exercise) {
    final updated = analyticsController.syncGoalProgressFromExercise(
      exercise: exercise,
      goals: List.from(_goals),
      isMetric: isMetric,
    );
    bool changed = false;
    for (final g in updated) {
      final idx = _goals.indexWhere((og) => og.id == g.id);
      if (idx != -1 && _goals[idx].progress != g.progress) {
        _goals[idx] = g;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      _saveGoals();
    }
  }


  SharedPreferences? _prefs;

  Future<void> loadFromStorage() async {
    _prefs = await SharedPreferences.getInstance();
    await analyticsController.loadModel();
    notifyListeners();
  }
}