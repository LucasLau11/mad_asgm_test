import '../models/workout_model.dart';
import '../models/workout_exercise_model.dart';
import '../services/workout_database_service.dart';

class WorkoutController {
  // Singleton pattern
  static final WorkoutController _instance = WorkoutController._internal();
  factory WorkoutController() => _instance;
  WorkoutController._internal();

  final WorkoutDatabaseService _dbService = WorkoutDatabaseService();

  // --- Read Methods ---

  Future<List<Workout>> getAllWorkouts() async {
    return await _dbService.getAllWorkouts();
  }

  Future<Workout?> getWorkoutById(String id) async {
    final workouts = await _dbService.getAllWorkouts();
    try {
      return workouts.firstWhere((workout) => workout.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<Exercise>> getExercisesForWorkout(String workoutId) async {
    return await _dbService.getExercisesForWorkout(workoutId);
  }

  // --- Write Methods ---

  Future<void> addWorkout(Workout workout, List<Exercise> exercises) async {
    await _dbService.insertWorkout(workout);
    for (var exercise in exercises) {
      await _dbService.insertExercise(exercise);
    }
  }

  Future<void> updateWorkout(Workout workout, List<Exercise> exercises) async {
    // Update workout details
    await _dbService.insertWorkout(workout);
    
    // Clear and replace exercises for this workout
    await _dbService.deleteAllExercisesForWorkout(workout.id);
    for (var exercise in exercises) {
      await _dbService.insertExercise(exercise);
    }
  }

  Future<void> deleteWorkout(String id) async {
    await _dbService.deleteWorkout(id);
  }

  // Helper method to seed initial data if database is empty
  Future<void> seedDatabaseIfNeeded() async {
    final workouts = await getAllWorkouts();
    if (workouts.isEmpty) {
      final initialWorkout = Workout(
        id: '1',
        name: 'Leg Workout',
        description: '4 exercise - 45 min',
        exerciseCount: 1,
        durationMinutes: 45,
        difficulty: 'Beginner',
        color: '0xFFD4FF6E',
      );

      final initialExercises = [
        Exercise(
          id: '1',
          workoutId: '1',
          name: 'Squats',
          sets: 3,
          reps: 12,
          instructions: '1) Stand with feet shoulder-width apart...\n2) Lower until thighs are parallel...',
          imageUrls: ['https://images.unsplash.com/photo-1566241142559-40e1dab266c6?w=800&q=80'],
        ),
      ];

      await addWorkout(initialWorkout, initialExercises);
    }
  }
}
