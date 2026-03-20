class HealthRecordModel {
  final int id;
  final int heartRate;
  final double waterIntake;
  final double weight;
  final String createdOn;

  HealthRecordModel({
    required this.id,
    required this.heartRate,
    required this.waterIntake,
    required this.weight,
    required this.createdOn,
  });

  // convert database row to HealthRecordModel object
  factory HealthRecordModel.fromJson(Map<String, dynamic> data) => HealthRecordModel(
    id: data['id'],
    heartRate: data['heartRate'],
    waterIntake: data['waterIntake'],
    weight: data['weight'],
    createdOn: data['createdOn'],
  );

  // convert HealthRecordModel object to database row
  Map<String, dynamic> toMap() => {
    'id': id,
    'heartRate': heartRate,
    'waterIntake': waterIntake,
    'weight': weight,
    'createdOn': createdOn,
  };
}