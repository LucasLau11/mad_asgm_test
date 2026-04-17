import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/analytic_model/analytics_goal_model.dart';
import '../models/exercise_model/exercise_model.dart';
import '../services/database/exercise_database_service.dart';
import '../services/database/workout_database_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Muscle group enum
//  Order MUST match the model's output layer: 0=upper, 1=lower, 2=core, 3=cardio
// ─────────────────────────────────────────────────────────────────────────────
enum MuscleGroup { upper, lower, core, cardio }

// ─────────────────────────────────────────────────────────────────────────────
//  A single workout log entry used by the ML pipeline
// ─────────────────────────────────────────────────────────────────────────────
class WorkoutEntry {
  final String exercise;
  final String detail;
  final int daysAgo;

  const WorkoutEntry({
    required this.exercise,
    required this.detail,
    required this.daysAgo,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
//  AnalyticsController
//
//  All data is now loaded from the real databases.
//  Call loadData() once (from AnalyticsAppState or initState) before using
//  any getters or generateRecommendation().
// ═════════════════════════════════════════════════════════════════════════════
class AnalyticsController {

  // ── TFLite interpreter ──────────────────────────────────────────────────
  Interpreter? _interpreter;
  bool _modelLoaded = false;

  // ── Cached data loaded from DBs ─────────────────────────────────────────
  List<WorkoutEntry> _workoutHistory = [];

  // Calorie chart: keyed by period, values are the data points
  Map<String, List<double>> _calorieData = {
    'Daily':   [0, 0, 0, 0, 0, 0, 0],
    'Weekly':  [0, 0, 0, 0],
    'Monthly': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  };

  int _last7DaysKcal = 0;
  int _allTimeKcal   = 0;
  int _averageKcal   = 0;

  // ── Public getters ───────────────────────────────────────────────────────
  Map<String, List<double>> get calorieData   => _calorieData;
  int get last7DaysKcal                       => _last7DaysKcal;
  int get allTimeKcal                         => _allTimeKcal;
  int get averageKcal                         => _averageKcal;
  String get daysSummary                      => '7 days';
  List<WorkoutEntry> get workoutHistory       => List.unmodifiable(_workoutHistory);

  // ══════════════════════════════════════════════════════════════════════════
  //  DATA LOADING — reads both databases and builds all derived values
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> loadData() async {
    final now = DateTime.now();

    // ── 1. Load cardio exercises (ExerciseType: walking/jogging/running) ───
    final exercises = await DatabaseService().getAllExercises();

    // ── 2. Load strength/core workouts (completed workout sessions) ────────
    // WorkoutDatabaseService stores workout definitions + their exercises.
    // We treat each saved workout as a completed session logged on its
    // creation date. We read all workouts and their exercises to infer
    // muscle group and use the workout's durationMinutes for calories.
    final allWorkouts = await WorkoutDatabaseService().getAllWorkouts();

    // ── 3. Build WorkoutEntry list (last 7 days) for the ML pipeline ───────
    final entries = <WorkoutEntry>[];

    // From cardio exercises
    for (final ex in exercises) {
      final daysAgo = now.difference(ex.startTime).inDays;
      if (daysAgo > 7) continue;
      final typeLabel = _exerciseTypeLabel(ex.type);
      final detail = ex.distanceKm != null && ex.distanceKm! > 0
          ? '${ex.distanceKm!.toStringAsFixed(1)} km'
          : ex.steps != null && ex.steps! > 0
          ? '${ex.steps} steps'
          : '${ex.durationMinutes} min';
      entries.add(WorkoutEntry(exercise: typeLabel, detail: detail, daysAgo: daysAgo));
    }

    // From strength/core workouts — fetch exercises for each workout to
    // map their names into the knowledge base for a richer signal.
    for (final workout in allWorkouts) {
      // Use workout createdAt if available; fall back to now
      // WorkoutModel doesn't store a date, so we assume recent completions.
      // If your WorkoutModel gains a completedAt field, swap it in here.
      // For now we treat every saved workout as completed today (daysAgo = 0).
      final workoutExercises =
      await WorkoutDatabaseService().getExercisesForWorkout(workout.id);
      if (workoutExercises.isEmpty) continue;
      final firstName = workoutExercises.first.name;
      entries.add(WorkoutEntry(
        exercise: firstName,
        detail: '${workout.durationMinutes ?? workout.exerciseCount ?? 1} ${workout.durationMinutes != null ? "min" : "sets"}',
        daysAgo: 0,
      ));
    }

    _workoutHistory = entries;

    // ── 4. Build calorie chart data ────────────────────────────────────────
    _buildCalorieChartData(exercises, now);

    // ── 5. Compute summary stats ───────────────────────────────────────────
    _computeStats(exercises, now);
  }

  // ── Exercise type → human-readable name (matches knowledge base keys) ───
  String _exerciseTypeLabel(ExerciseType type) {
    switch (type) {
      case ExerciseType.walking: return 'walking';
      case ExerciseType.jogging: return 'jogging';
      case ExerciseType.running: return 'running';
    }
  }

  // ── Build chart data from exercise DB ───────────────────────────────────
  void _buildCalorieChartData(List<Exercise> exercises, DateTime now) {
    // Daily — last 7 days, one bar per day
    final dailyKcal = List<double>.filled(7, 0);
    for (final ex in exercises) {
      final daysAgo = now.difference(ex.startTime).inDays;
      if (daysAgo < 7) {
        dailyKcal[6 - daysAgo] += (ex.energyExpended ?? 0).toDouble();
      }
    }

    // Weekly — last 4 weeks, one bar per week
    final weeklyKcal = List<double>.filled(4, 0);
    for (final ex in exercises) {
      final daysAgo = now.difference(ex.startTime).inDays;
      if (daysAgo < 28) {
        final weekIdx = daysAgo ~/ 7;
        weeklyKcal[3 - weekIdx] += (ex.energyExpended ?? 0).toDouble();
      }
    }

    // Monthly — last 12 months, one bar per month
    final monthlyKcal = List<double>.filled(12, 0);
    for (final ex in exercises) {
      final monthsAgo = (now.year - ex.startTime.year) * 12 +
          (now.month - ex.startTime.month);
      if (monthsAgo >= 0 && monthsAgo < 12) {
        monthlyKcal[11 - monthsAgo] += (ex.energyExpended ?? 0).toDouble();
      }
    }

    _calorieData = {
      'Daily':   dailyKcal,
      'Weekly':  weeklyKcal,
      'Monthly': monthlyKcal,
    };
  }

  // ── Summary stats ────────────────────────────────────────────────────────
  void _computeStats(List<Exercise> exercises, DateTime now) {
    int last7 = 0;
    int allTime = 0;
    final dailyTotals = <String, int>{};

    for (final ex in exercises) {
      final kcal = ex.energyExpended ?? 0;
      allTime += kcal;

      final daysAgo = now.difference(ex.startTime).inDays;
      if (daysAgo < 7) last7 += kcal;

      final dayKey = ex.startTime.toIso8601String().substring(0, 10);
      dailyTotals[dayKey] = (dailyTotals[dayKey] ?? 0) + kcal;
    }

    _last7DaysKcal = last7;
    _allTimeKcal   = allTime;
    _averageKcal   = dailyTotals.isEmpty
        ? 0
        : (allTime / dailyTotals.length).round();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MODEL LOADING
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> loadModel() async {
    if (_modelLoaded) return;
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/ml/workout_recommender.tflite',
      );
      _modelLoaded = true;
    } catch (_) {
      _modelLoaded = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  KNOWLEDGE BASE — exercise name → muscle group
  // ══════════════════════════════════════════════════════════════════════════
  static const Map<String, MuscleGroup> _exerciseKnowledgeBase = {
    // Cardio
    'running'          : MuscleGroup.cardio,
    'jogging'          : MuscleGroup.cardio,
    'cycling'          : MuscleGroup.cardio,
    'swimming'         : MuscleGroup.cardio,
    'jump rope'        : MuscleGroup.cardio,
    'rowing'           : MuscleGroup.cardio,
    'elliptical'       : MuscleGroup.cardio,
    'hiking'           : MuscleGroup.cardio,
    'walking'          : MuscleGroup.cardio,
    'stair climbing'   : MuscleGroup.cardio,
    'burpees'          : MuscleGroup.cardio,
    // Lower body
    'squats'           : MuscleGroup.lower,
    'lunges'           : MuscleGroup.lower,
    'leg press'        : MuscleGroup.lower,
    'deadlift'         : MuscleGroup.lower,
    'calf raises'      : MuscleGroup.lower,
    'leg curls'        : MuscleGroup.lower,
    'glute bridges'    : MuscleGroup.lower,
    'step-ups'         : MuscleGroup.lower,
    // Upper body
    'push-ups'         : MuscleGroup.upper,
    'pull-ups'         : MuscleGroup.upper,
    'bench press'      : MuscleGroup.upper,
    'shoulder press'   : MuscleGroup.upper,
    'bicep curls'      : MuscleGroup.upper,
    'tricep dips'      : MuscleGroup.upper,
    'lat pulldown'     : MuscleGroup.upper,
    'rows'             : MuscleGroup.upper,
    'chest fly'        : MuscleGroup.upper,
    'weight lifting'   : MuscleGroup.upper,
    // Core
    'plank'            : MuscleGroup.core,
    'sit-ups'          : MuscleGroup.core,
    'crunches'         : MuscleGroup.core,
    'russian twists'   : MuscleGroup.core,
    'leg raises'       : MuscleGroup.core,
    'mountain climbers': MuscleGroup.core,
    'flutter kicks'    : MuscleGroup.core,
  };

  // ══════════════════════════════════════════════════════════════════════════
  //  SUGGESTION BANK
  // ══════════════════════════════════════════════════════════════════════════
  static const Map<MuscleGroup, List<String>> _suggestions = {
    MuscleGroup.upper: [
      'push-ups or bench press',
      'shoulder press and bicep curls',
      'pull-ups and tricep dips',
      'weight lifting — focus on chest and back',
    ],
    MuscleGroup.lower: [
      'squats and lunges',
      'deadlifts and calf raises',
      'leg press and glute bridges',
      'step-ups and leg curls',
    ],
    MuscleGroup.core: [
      'planks and crunches',
      'russian twists and leg raises',
      'mountain climbers and flutter kicks',
      'a 15-minute core circuit',
    ],
    MuscleGroup.cardio: [
      'a brisk 20-minute run',
      'cycling for 30 minutes',
      'jump rope intervals',
      'a swim or rowing session',
    ],
  };

  // ══════════════════════════════════════════════════════════════════════════
  //  STEP 1 — FATIGUE SCORING
  // ══════════════════════════════════════════════════════════════════════════
  static const double _baseScore   = 10.0;
  static const int    _decayWindow = 7;
  static const double _maxScore    = 10.0;

  List<double> _computeNormalisedFatigue() {
    final raw = {
      MuscleGroup.upper:  0.0,
      MuscleGroup.lower:  0.0,
      MuscleGroup.core:   0.0,
      MuscleGroup.cardio: 0.0,
    };

    for (final entry in _workoutHistory) {
      if (entry.daysAgo > _decayWindow) continue;
      final group = _classifyExercise(entry.exercise);
      raw[group] = raw[group]! + (_baseScore / (entry.daysAgo + 1));
    }

    return [
      (raw[MuscleGroup.upper]!  / _maxScore).clamp(0.0, 1.0),
      (raw[MuscleGroup.lower]!  / _maxScore).clamp(0.0, 1.0),
      (raw[MuscleGroup.core]!   / _maxScore).clamp(0.0, 1.0),
      (raw[MuscleGroup.cardio]! / _maxScore).clamp(0.0, 1.0),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STEP 2 — GOAL BIAS
  // ══════════════════════════════════════════════════════════════════════════
  static const Set<String> _cardioGoalTypes = {
    'Cal Burned', 'Steps Walked', 'Km Ran', 'Miles Ran',
    'Weight Lost (kg)', 'Weight Lost (lbs)',
  };

  double _computeGoalBias(List<GoalModel> goals) {
    if (goals.isEmpty) return 0.0;
    final cardioCount =
        goals.where((g) => _cardioGoalTypes.contains(g.goalType)).length;
    final ratio = cardioCount / goals.length;
    if (ratio == 0.0) return 0.0;
    if (ratio < 0.6)  return 0.5;
    return 1.0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STEP 3 — TFLITE INFERENCE
  // ══════════════════════════════════════════════════════════════════════════
  MuscleGroup _runInference(List<double> fatigue, double goalBias) {
    if (!_modelLoaded || _interpreter == null) {
      return MuscleGroup.values[_argMin(fatigue)];
    }

    final input  = [[fatigue[0], fatigue[1], fatigue[2], fatigue[3], goalBias]];
    final output = List.filled(4, 0.0).reshape([1, 4]);

    _interpreter!.run(input, output);

    final probs = List<double>.from(output[0] as List);
    return MuscleGroup.values[_argMax(probs)];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ══════════════════════════════════════════════════════════════════════════
  String generateRecommendation({List<GoalModel> goals = const []}) {
    if (_workoutHistory.isEmpty) {
      return 'No workouts logged yet. Complete a cardio session or a workout program and we\'ll personalise your recommendation!';
    }

    final fatigue      = _computeNormalisedFatigue();
    final goalBias     = _computeGoalBias(goals);
    final recommended  = _runInference(fatigue, goalBias);
    final options      = _suggestions[recommended]!;
    final suggestion   = options[DateTime.now().weekday % options.length];
    final opening      = _buildOpeningSentence();
    final groupLabel   = _groupLabel(recommended);
    final goalSentence = _buildGoalSentence(goals, recommended);

    return '$opening'
        'Your $groupLabel muscles are the most rested today — '
        'try $suggestion.$goalSentence';
  }

  // ── Goal progress update — called when a calorie/step/distance goal
  //    should be incremented from a newly completed exercise session.
  //    Returns the updated GoalModel list so AnalyticsAppState can persist it.
  List<GoalModel> syncGoalProgressFromExercise({
    required Exercise exercise,
    required List<GoalModel> goals,
    required bool isMetric,
  }) {
    final updated = <GoalModel>[];

    for (final goal in goals) {
      int delta = 0;

      switch (goal.goalType) {
        case 'Cal Burned':
          delta = exercise.energyExpended ?? 0;
          break;
        case 'Steps Walked':
          delta = exercise.steps ?? 0;
          break;
        case 'Km Ran':
          if (isMetric) delta = (exercise.distanceKm ?? 0).round();
          break;
        case 'Miles Ran':
          if (!isMetric) {
            delta = ((exercise.distanceKm ?? 0) * 0.621371).round();
          }
          break;
        default:
          break;
      }

      if (delta > 0) {
        final target = int.tryParse(goal.target) ?? 0;
        final newProgress = (goal.progress + delta).clamp(0, target * 10);
        updated.add(GoalModel(
          id: goal.id,
          goalType: goal.goalType,
          target: goal.target,
          deadline: goal.deadline,
          reason: goal.reason,
          progress: newProgress,
        ));
      } else {
        updated.add(goal);
      }
    }

    return updated;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  MuscleGroup _classifyExercise(String exercise) {
    final key = exercise.toLowerCase().trim();
    if (_exerciseKnowledgeBase.containsKey(key)) {
      return _exerciseKnowledgeBase[key]!;
    }
    for (final entry in _exerciseKnowledgeBase.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    return MuscleGroup.cardio;
  }

  String _buildOpeningSentence() {
    final recent = _workoutHistory
        .where((w) => w.daysAgo == 0 || w.daysAgo == 1)
        .toList();
    if (recent.isEmpty) return 'You haven\'t logged anything recently. ';

    final yesterday = _workoutHistory.where((w) => w.daysAgo == 1).toList();
    final today     = _workoutHistory.where((w) => w.daysAgo == 0).toList();

    if (today.isNotEmpty) {
      final parts = today.map((w) => '${w.detail} of ${w.exercise}').toList();
      final summary = _joinList(parts);
      return 'Today you did $summary. ';
    }

    if (yesterday.isNotEmpty) {
      final parts = yesterday.map((w) => '${w.detail} of ${w.exercise}').toList();
      final summary = _joinList(parts);
      return 'Yesterday you did $summary. ';
    }

    return '';
  }

  String _joinList(List<String> parts) {
    if (parts.length == 1) return parts.first;
    if (parts.length == 2) return '${parts[0]} and ${parts[1]}';
    return '${parts.sublist(0, parts.length - 1).join(', ')}, and ${parts.last}';
  }

  String _buildGoalSentence(List<GoalModel> goals, MuscleGroup recommended) {
    if (goals.isEmpty) return '';
    for (final goal in goals) {
      final isCardio = _cardioGoalTypes.contains(goal.goalType);
      final matches  = (recommended == MuscleGroup.cardio) == isCardio;
      if (matches) {
        final targetInt = int.tryParse(goal.target) ?? 0;
        final remaining = targetInt - goal.progress;
        final tip = remaining > 0
            ? ' $remaining ${goal.goalType} still to go!'
            : ' You\'re on track!';
        return ' This supports your "${goal.goalType}" goal.$tip';
      }
    }
    return '';
  }

  String _groupLabel(MuscleGroup group) {
    switch (group) {
      case MuscleGroup.upper:  return 'upper body';
      case MuscleGroup.lower:  return 'lower body';
      case MuscleGroup.core:   return 'core';
      case MuscleGroup.cardio: return 'cardio';
    }
  }

  int _argMax(List<double> list) {
    int idx = 0;
    for (int i = 1; i < list.length; i++) {
      if (list[i] > list[idx]) idx = i;
    }
    return idx;
  }

  int _argMin(List<double> list) {
    int idx = 0;
    for (int i = 1; i < list.length; i++) {
      if (list[i] < list[idx]) idx = i;
    }
    return idx;
  }

  void dispose() => _interpreter?.close();
}