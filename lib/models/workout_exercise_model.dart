class Exercise {
  final String id;
  final String workoutId;
  final String name;
  final int sets;
  final int reps;
  final String instructions;
  final List<String> imageUrls;

  Exercise({
    required this.id,
    required this.workoutId,
    required this.name,
    required this.sets,
    required this.reps,
    required this.instructions,
    required this.imageUrls,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutId': workoutId,
      'name': name,
      'sets': sets,
      'reps': reps,
      'instructions': instructions,
      'image_urls': imageUrls,
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
      imageUrls: List<String>.from(map['image_urls'] ?? []),    );
  }
}