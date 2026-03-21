class Workout {
  final String id;
  final String name;
  final String description;
  final int exerciseCount;
  final int durationMinutes;
  final String difficulty;
  final String color; // Store color as hex string

  Workout({
    required this.id,
    required this.name,
    required this.description,
    required this.exerciseCount,
    required this.durationMinutes,
    required this.difficulty,
    required this.color,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'exerciseCount': exerciseCount,
      'durationMinutes': durationMinutes,
      'difficulty': difficulty,
      'color': color,
    };
  }

  // Create from Map
  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      exerciseCount: map['exerciseCount'],
      durationMinutes: map['durationMinutes'],
      difficulty: map['difficulty'],
      color: map['color'],
    );
  }
}