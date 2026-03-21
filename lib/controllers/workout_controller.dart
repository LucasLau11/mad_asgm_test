import '../models/workout_model.dart';
import '../models/workout_exercise_model.dart';

class WorkoutController {
  // Singleton pattern
  static final WorkoutController _instance = WorkoutController._internal();
  factory WorkoutController() => _instance;
  WorkoutController._internal();

  // Mock data - replace with database later
  final List<Workout> _workouts = [
    Workout(
      id: '1',
      name: 'Leg Workout',
      description: '4 exercise - 45 min',
      exerciseCount: 4,
      durationMinutes: 45,
      difficulty: 'Beginner',
      color: '0xFFD4FF6E',
    ),
    Workout(
      id: '2',
      name: 'Chest Workout',
      description: '4 exercise - 45 min',
      exerciseCount: 4,
      durationMinutes: 45,
      difficulty: 'Beginner',
      color: '0xFFAEC6F5',
    ),
    Workout(
      id: '3',
      name: 'Arm Workout',
      description: '4 exercise - 45 min',
      exerciseCount: 4,
      durationMinutes: 45,
      difficulty: 'Beginner',
      color: '0xFFFFA7A7',
    ),
  ];

  final Map<String, List<Exercise>> _exercises = {
    '1': [
      Exercise(
        id: '1',
        workoutId: '1',
        name: 'Squats',
        sets: 3,
        reps: 12,
        instructions: '1) Stand with feet shoulder-width apart, toes slightly out.\n2) Keep chest up and core braced throughout.\n3) Lower until thighs are parallel to the floor.\n4) Drive through heels to return to start.',
      ),
      Exercise(
        id: '2',
        workoutId: '1',
        name: 'Lunges',
        sets: 3,
        reps: 10,
        instructions: '1) Step forward with one leg.\n2) Lower hips until both knees are bent at 90 degrees.\n3) Push back to starting position.\n4) Alternate legs.',
      ),
      Exercise(
        id: '3',
        workoutId: '1',
        name: 'Leg Press',
        sets: 3,
        reps: 15,
        instructions: '1) Sit in leg press machine.\n2) Place feet shoulder-width apart.\n3) Push platform away.\n4) Lower slowly back down.',
      ),
    ],
    '2': [
      Exercise(
        id: '4',
        workoutId: '2',
        name: 'Push-ups',
        sets: 3,
        reps: 12,
        instructions: '1) Start in plank position.\n2) Lower body until chest nearly touches floor.\n3) Push back up.\n4) Keep core tight throughout.',
      ),
      Exercise(
        id: '5',
        workoutId: '2',
        name: 'Bench Press',
        sets: 3,
        reps: 10,
        instructions: '1) Lie on bench.\n2) Grip bar slightly wider than shoulders.\n3) Lower bar to chest.\n4) Press back up.',
      ),
    ],
    '3': [
      Exercise(
        id: '6',
        workoutId: '3',
        name: 'Bicep Curls',
        sets: 3,
        reps: 12,
        instructions: '1) Stand with dumbbells at sides.\n2) Curl weights up.\n3) Lower slowly.\n4) Keep elbows stationary.',
      ),
      Exercise(
        id: '7',
        workoutId: '3',
        name: 'Tricep Dips',
        sets: 3,
        reps: 10,
        instructions: '1) Place hands on bench behind you.\n2) Lower body down.\n3) Push back up.\n4) Keep core engaged.',
      ),
    ],
  };

  // Get all workouts
  List<Workout> getAllWorkouts() {
    return _workouts;
  }

  // Get workout by ID
  Workout? getWorkoutById(String id) {
    try {
      return _workouts.firstWhere((workout) => workout.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get exercises for a workout
  List<Exercise> getExercisesForWorkout(String workoutId) {
    return _exercises[workoutId] ?? [];
  }

  // Get exercise by ID
  Exercise? getExerciseById(String exerciseId) {
    for (var exerciseList in _exercises.values) {
      try {
        return exerciseList.firstWhere((ex) => ex.id == exerciseId);
      } catch (e) {
        continue;
      }
    }
    return null;
  }

// TODO: Add database methods later
// Future<void> addWorkout(Workout workout) async {}
// Future<void> updateWorkout(Workout workout) async {}
// Future<void> deleteWorkout(String id) async {}
}