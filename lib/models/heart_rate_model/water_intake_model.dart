class WaterIntakeModel {
  final int id;
  final double amountMl;
  final String beverageType;
  final String time;
  final String note;
  final String createdOn;

  WaterIntakeModel({
    required this.id,
    required this.amountMl,
    required this.beverageType,
    required this.time,
    required this.note,
    required this.createdOn,
  });

  // database row to WaterIntakeModel object
  factory WaterIntakeModel.fromJson(Map<String, dynamic> data) => WaterIntakeModel(
    id: data['id'],
    amountMl: data['amountMl'],
    beverageType: data['beverageType'],
    time: data['time'],
    note: data['note'],
    createdOn: data['createdOn'],
  );

  // waterIntakeModel object to database row
  Map<String, dynamic> toMap() => {
    'id': id,
    'amountMl': amountMl,
    'beverageType': beverageType,
    'time': time,
    'note': note,
    'createdOn': createdOn,
  };
}