class HeartRateModel {
  final int id;
  final int bpm;
  final String status;  // 'Normal', 'Elevated', 'High', 'Low'
  final String note;
  final String createdOn;

  HeartRateModel({
    required this.id,
    required this.bpm,
    required this.status,
    required this.note,
    required this.createdOn,
  });

  factory HeartRateModel.fromJson(Map<String, dynamic> data) => HeartRateModel(
    id: data['id'],
    bpm: data['bpm'],
    status: data['status'],
    note: data['note'],
    createdOn: data['createdOn'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'bpm': bpm,
    'status': status,
    'note': note,
    'createdOn': createdOn,
  };

  // Helper: automatically get status from bpm value
  static String getStatus(int bpm) {
    if (bpm < 60) return 'Low';
    if (bpm <= 100) return 'Normal';
    if (bpm <= 120) return 'Elevated';
    return 'High';
  }

// Helper: get status color (use in views)
// Low = blue, Normal = green, Elevated = orange, High = red
}