import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../controllers/exercise_controller.dart';
import '../../controllers/pedometer_controller.dart';
import '../../models/exercise_model/exercise_model.dart';
import '../../models/analytic_model/analytics_app_state.dart';
import '../../services/exercise_calorie_calculator.dart';
import 'exercise_add_view.dart';
import 'exercise_detail_view.dart';
import 'exercise_live_view.dart';
import 'exercise_goal_settings_view.dart';

class ExerciseListView extends StatefulWidget {
  const ExerciseListView({Key? key}) : super(key: key);

  @override
  State<ExerciseListView> createState() => _ExerciseListViewState();
}

class _ExerciseListViewState extends State<ExerciseListView> {
  Timer? _bannerRefreshTimer;
  final CalorieCalculator _calorieCalculator = CalorieCalculator();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pedometer = Provider.of<PedometerController>(context, listen: false);

      // Wire the auto-save callback BEFORE starting detection.
      pedometer.onAutoSave = _handleAutoSave;

      // ensureAutoDetectRunning() is idempotent — safe to call every time
      // the widget mounts (e.g. hot-restart, tab switch after kill).
      // It checks an internal flag so the service only starts once.
      print('[ExerciseList] calling ensureAutoDetectRunning');
      pedometer.ensureAutoDetectRunning();
    });

    // ADD THIS — ensures the Consumer2 rebuilds when walk is detected
    // even if the notification fires between frames
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PedometerController>(context, listen: false)
          .addListener(_onPedometerUpdate);
    });

    // Redraw every 20 s so "X min" in the banner stays current.
    _bannerRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  // ADD this method
  void _onPedometerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bannerRefreshTimer?.cancel();
    // Clear the callback so stale closures don't fire after unmount.
    // Do NOT stop the service — it must keep running in the background.
    final pedometer =
    Provider.of<PedometerController>(context, listen: false);
    pedometer.onAutoSave = null;
    pedometer.removeListener(_onPedometerUpdate); // ADD THIS
    super.dispose();
  }

  String _getTodayDate() {
    final now = DateTime.now();
    final days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  // ── Navigate to live workout ─────────────────────────────────────────────────
  Future<void> _launchLiveView(BuildContext context, ExerciseType type) async {
    final pedometer = Provider.of<PedometerController>(context, listen: false);

    // Pause cadence evaluator so the live session's steps don't create a
    // false auto-walk banner when the user returns.
    await pedometer.pauseAutoDetect();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveExerciseView(exerciseType: type),
      ),
    );

    // Resume after returning — resets cadence baseline so no false trigger.
    // if (mounted) {
    //   await pedometer.resumeAutoDetect();
    // }

    await pedometer.resumeAutoDetect();
  }

  // ── Auto-save handler (called by PedometerController) ───────────────────────
  Future<void> _handleAutoSave({
    required DateTime startTime,
    required int steps,
    required int durationMinutes,
  }) async {
    if (!mounted) return;

    final exerciseController =
    Provider.of<ExerciseController>(context, listen: false);

    final calories = steps > 0
        ? _calorieCalculator.estimateCaloriesFromSteps(steps)
        : null;

    final exercise = Exercise(
      title: _generateAutoTitle(startTime),
      type: ExerciseType.walking,
      startTime: startTime,
      durationMinutes: durationMinutes,
      steps: steps > 0 ? steps : null,
      energyExpended: calories,
      isAutoDetected: true,
    );

    final success = await exerciseController.createExercise(exercise);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '🚶 Walk auto-saved ($durationMinutes min)'
                : 'Failed to save detected walk',
          ),
          backgroundColor: success ? const Color(0xFF43A047) : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _generateAutoTitle(DateTime start) {
    final h = start.hour;
    if (h < 12) return 'Morning Walk';
    if (h < 17) return 'Afternoon Walk';
    if (h < 21) return 'Evening Walk';
    return 'Night Walk';
  }

  // ── Manual "Save Walk" from banner (user-initiated) ──────────────────────────
  Future<void> _saveAutoDetectedWalk(BuildContext context) async {
    final pedometer =
    Provider.of<PedometerController>(context, listen: false);
    final exerciseController =
    Provider.of<ExerciseController>(context, listen: false);

    final startTime = pedometer.autoDetectStartTime ?? DateTime.now();
    final durationMinutes =
    DateTime.now().difference(startTime).inMinutes.clamp(1, 9999);
    final steps = pedometer.autoDetectedSteps;

    String title = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final titleController = TextEditingController(
          text: 'Walk ${TimeOfDay.fromDateTime(startTime).format(context)}',
        );
        return AlertDialog(
          title: const Text('Save detected walk'),
          content: TextField(
            controller: titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'e.g. Afternoon Walk',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                pedometer.dismissAutoDetect();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C6FDC),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                title = titleController.text.trim();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (title.isEmpty) return;

    final calories = steps > 0
        ? _calorieCalculator.estimateCaloriesFromSteps(steps)
        : null;

    final exercise = Exercise(
      title: title,
      type: ExerciseType.walking,
      startTime: startTime,
      durationMinutes: durationMinutes,
      steps: steps > 0 ? steps : null,
      energyExpended: calories,
      isAutoDetected: true,
    );

    final success = await exerciseController.createExercise(exercise);
    pedometer.resetAutoDetect();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Walk saved!' : 'Failed to save walk'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AnalyticsAppState>();
    final isDark = appState.darkMode;
    final bg = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exercise',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    _getTodayDate(),
                    style: TextStyle(fontSize: 13, color: subTextColor),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Consumer2<ExerciseController, PedometerController>(
                  builder: (context, controller, pedometer, child) {
                    if (controller.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ListView(
                      // padding: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(10),
                      children: [
                        //console not working, so I commented it out
                        // Text(
                        //   'Total steps taken since factory new: ${pedometer.totalSteps}',
                        //   style: const TextStyle(fontSize: 16, color: Colors.blue),
                        // ),

                        // ── Auto-walk banner ──────────────────────────────────
                        // Shows automatically whenever the background service
                        // detects walking AND the user is not in a live session.
                        // isAutoWalkDetected already checks _autoDetectDismissed
                        // and _autoDetectPaused internally, so no extra guards needed.
                        if (pedometer.isAutoWalkDetected && !pedometer.isTracking)
                          _buildAutoWalkBanner(context, pedometer),

                        // ── Start workout card ────────────────────────────────
                        _buildStartWorkoutCard(context),
                        const SizedBox(height: 24),

                        // ── Today's Log ───────────────────────────────────────
                        if (controller.todayExercises.isNotEmpty) ...[
                          _buildSectionHeader("Today's Log", subTextColor),
                          const SizedBox(height: 16),
                          ...controller.todayExercises.map(
                                  (e) => _buildExerciseCard(context, e, isDark)),
                          const SizedBox(height: 24),
                        ],

                        // ── Past Log ──────────────────────────────────────────
                        if (controller.pastExercises.isNotEmpty) ...[
                          _buildSectionHeader('Past exercise Log', subTextColor),
                          const SizedBox(height: 16),
                          ...controller.pastExercises.map(
                                  (e) => _buildExerciseCard(context, e, isDark)),
                        ],

                        if (controller.exercises.isEmpty)
                          _buildEmptyState(context, isDark),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddExerciseView()),
        ),
        backgroundColor: const Color(0xFFD1D1D1),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  // ── Auto-walk banner ────────────────────────────────────────────────────
  Widget _buildAutoWalkBanner(
      BuildContext context, PedometerController pedometer) {
    final startTime = pedometer.autoDetectStartTime;
    final elapsed = startTime != null
        ? DateTime.now().difference(startTime)
        : Duration.zero;
    final minutes = elapsed.inMinutes;
    final steps = pedometer.autoDetectedSteps;
    final estimatedCalories =
    steps > 0 ? _calorieCalculator.estimateCaloriesFromSteps(steps) : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF43A047).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_walk,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Walk detected!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
              GestureDetector(
                onTap: () =>
                    Provider.of<PedometerController>(context, listen: false)
                        .dismissAutoDetect(),
                child: const Icon(Icons.close, color: Colors.white70, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Stats row
          Row(
            children: [
              _buildBannerStat(Icons.access_time, '$minutes min', 'Duration'),
              const SizedBox(width: 12),
              if (steps > 0) ...[
                _buildBannerStat(Icons.directions_walk, '$steps', 'Steps'),
                const SizedBox(width: 12),
                _buildBannerStat(
                    Icons.local_fire_department, '$estimatedCalories', 'Cal'),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _saveAutoDetectedWalk(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'Save Walk',
                        style: TextStyle(
                          color: Color(0xFF43A047),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _launchLiveView(context, ExerciseType.walking),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white60),
                    ),
                    child: const Center(
                      child: Text(
                        'Track Live',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color? color) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 16, color: color, fontWeight: FontWeight.w400),
    );
  }

  // ── Start workout card ───────────────────────────────────────────────────────
  Widget _buildStartWorkoutCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C6FDC), Color(0xFF9D8FE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C6FDC).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.play_circle_filled,
                  color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Text(
                'Start a Workout',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const GoalSettingsView()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Track your activity in real-time with GPS and step counting',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildQuickStartButton(
                  context, ExerciseType.walking, 'Walking', Icons.directions_walk),
              const SizedBox(width: 12),
              _buildQuickStartButton(
                  context, ExerciseType.jogging, 'Jogging', Icons.run_circle),
              const SizedBox(width: 12),
              _buildQuickStartButton(
                  context, ExerciseType.running, 'Running', Icons.directions_run),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartButton(
      BuildContext context, ExerciseType type, String label, IconData icon) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _launchLiveView(context, type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Exercise card ────────────────────────────────────────────────────────────
  Widget _buildExerciseCard(
      BuildContext context, Exercise exercise, bool isDark) {
    final bg = exercise.type.cardBackground;
    final accent = exercise.type.cardAccent;
    final iconColor = exercise.type.cardAccent;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBg = isDark
        ? Color.alphaBlend(bg.withOpacity(0.3), const Color(0xFF1E1E1E))
        : bg;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ExerciseDetailView(exercise: exercise)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'created at ${exercise.formattedTime}',
                          style: TextStyle(fontSize: 11, color: subColor),
                        ),
                        if (exercise.isAutoDetected) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline,
                                    size: 10, color: accent),
                                const SizedBox(width: 3),
                                Text(
                                  'auto',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: accent,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      exercise.title.isNotEmpty
                          ? exercise.title
                          : exercise.type.displayName,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: titleColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.distanceKm != null
                          ? '${exercise.formattedDistance} in ${exercise.formattedDuration}'
                          : exercise.formattedDuration,
                      style: TextStyle(fontSize: 13, color: subColor),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(exercise.formattedDate,
                            style:
                            TextStyle(fontSize: 12, color: subColor)),
                        const Spacer(),
                        if (exercise.steps != null)
                          Text(exercise.formattedSteps,
                              style:
                              TextStyle(fontSize: 12, color: subColor)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(exercise.type.icon, color: iconColor, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center,
                size: 80,
                color: isDark ? Colors.grey[700] : Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No exercises yet',
                style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Tap the + button to add your first exercise',
                style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[600] : Colors.grey[400]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}