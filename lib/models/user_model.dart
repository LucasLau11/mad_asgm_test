class UserModel {
  final int id;
  final String username;
  final String passwordHash;
  final String email;
  final String createdOn;

  UserModel({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.email,
    required this.createdOn,
  });

  factory UserModel.fromJson(Map<String, dynamic> data) => UserModel(
    id: data['id'],
    username: data['username'],
    passwordHash: data['passwordHash'],
    email: data['email'] ?? '',
    createdOn: data['createdOn'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'username': username,
    'passwordHash': passwordHash,
    'email': email,
    'createdOn': createdOn,
  };
}

