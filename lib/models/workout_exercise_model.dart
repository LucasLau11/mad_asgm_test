class Exercise {
  final String id;
  final String workoutId;
  final String name;
  final int sets;
  final int reps;
  final String instructions;
  final String? videoUrl;

  Exercise({
    required this.id,
    required this.workoutId,
    required this.name,
    required this.sets,
    required this.reps,
    required this.instructions,
    this.videoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutId': workoutId,
      'name': name,
      'sets': sets,
      'reps': reps,
      'instructions': instructions,
      'videoUrl': videoUrl,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      workoutId: map['workoutId'],
      name: map['name'],
      sets: map['sets'],
      reps: map['reps'],
      instructions: map['instructions'],
      videoUrl: map['videoUrl'],
    );
  }
}