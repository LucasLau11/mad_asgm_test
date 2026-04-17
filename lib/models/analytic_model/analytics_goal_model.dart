class GoalModel {
  final String id;
  final String goalType;
  final String target;
  final String deadline;
  final String reason;
  int progress;

  GoalModel({
    required this.id,
    required this.goalType,
    required this.target,
    required this.deadline,
    required this.reason,
    this.progress = 0,
  });

  String get displayTitle => '$progress/$target $goalType';
  String get displaySubtitle => deadline;

  Map<String, dynamic> toJson() => {
    'id': id,
    'goalType': goalType,
    'target': target,
    'deadline': deadline,
    'reason': reason,
    'progress': progress,
  };

  factory GoalModel.fromJson(Map<String, dynamic> json) => GoalModel(
    id: json['id'],
    goalType: json['goalType'],
    target: json['target'],
    deadline: json['deadline'],
    reason: json['reason'] ?? '',
    progress: json['progress'] ?? 0,
  );
}