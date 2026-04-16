class Workout {
  final String id;
  final int userId; // Link to UserModel.id
  final String name;
  final String description;
  final int exerciseCount;
  final int durationMinutes;
  final String difficulty;
  final String color;
 // final String imageUrl;

  Workout({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.exerciseCount,
    required this.durationMinutes,
    required this.difficulty,
    required this.color,
   // required this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'exerciseCount': exerciseCount,
      'durationMinutes': durationMinutes,
      'difficulty': difficulty,
      'color': color,
     // 'imageUrl': imageUrl,
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'],
      userId: map['userId'],
      name: map['name'],
      description: map['description'],
      exerciseCount: map['exerciseCount'],
      durationMinutes: map['durationMinutes'],
      difficulty: map['difficulty'],
      color: map['color'],
      //imageUrl: map['imageUrl'],
    );
  }
}
