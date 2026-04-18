import 'package:flutter/material.dart';
import 'package:mad_asgm/views/workout_view/workout_tracking_page.dart';
import '../../controllers/workout_controller.dart';
import '../../models/workout_model/workout_model.dart';
import '../../models/workout_model/workout_exercise_model.dart';
import 'workout_exercise_detail_page.dart';
import 'dart:io';
class WorkoutDetailPage extends StatefulWidget {
  final Workout workout;

  const WorkoutDetailPage({
    Key? key,
    required this.workout,
  }) : super(key: key);

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  final WorkoutController _controller = WorkoutController();
  List<Exercise> _exercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
    // Properly await the future result
    final exercises = await _controller.getExercisesForWorkout(widget.workout.id);
    setState(() {
      _exercises = exercises;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.workout.name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      Container(
                          height: 200,
                          width: double.infinity, // Ensures the container fills the width
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            // Move the image property here inside BoxDecoration
                            image: DecorationImage(
                              image: (widget.workout.imageUrl == null || widget.workout.imageUrl.isEmpty)
                                  ? const AssetImage('assets/images/fitpulse.png') as ImageProvider
                                  : FileImage(File(widget.workout.imageUrl)),
                              fit: BoxFit.cover,
                            ),
                          ),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.workout.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildInfoItem(widget.workout.goal, 'Goals')),
                                const SizedBox(width: 8), // Added small gap
                                Expanded(child: _buildInfoItem('${widget.workout.durationMinutes} mins', 'Time')),
                                const SizedBox(width: 8), // Added small gap
                                Expanded(child: _buildInfoItem(widget.workout.difficulty, 'Difficulty')),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text('Exercises (${_exercises.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 16),

                      if (_exercises.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No exercises in this workout'))),

                      ..._exercises.map((exercise) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildExerciseItem(exercise),
                      )),

                      const SizedBox(height: 24),

                      GestureDetector(
                        onTap: () {
                          if (_exercises.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkoutTrackingPage(
                                  exercises: _exercises,
                                  workoutName: widget.workout.name,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add exercises first')));
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(color: const Color(0xFFDAD9FF), borderRadius: BorderRadius.circular(16)),
                          child: const Center(
                            child: Text('Start Workout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87
          ),

          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          softWrap: false,

        ),
        const SizedBox(height: 4),
        Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])
        ),
      ],
    );
  }

  Widget _buildExerciseItem(Exercise exercise) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ExerciseDetailPage(exercise: exercise)));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(color: const Color(0xFFE8E4FF), borderRadius: BorderRadius.circular(12))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text('x ${exercise.reps}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${exercise.sets} sets', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 4),
                 Text('More >', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
