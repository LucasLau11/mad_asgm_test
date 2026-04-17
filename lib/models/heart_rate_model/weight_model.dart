class WeightModel {
  final int id;
  final double weightKg;
  final String note;
  final String createdOn;

  WeightModel({
    required this.id,
    required this.weightKg,
    required this.note,
    required this.createdOn,
  });

  factory WeightModel.fromJson(Map<String, dynamic> data) => WeightModel(
    id: data['id'],
    weightKg: data['weightKg'],
    note: data['note'],
    createdOn: data['createdOn'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'weightKg': weightKg,
    'note': note,
    'createdOn': createdOn,
  };
}