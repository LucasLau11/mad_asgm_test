class AnalyticsProfileModel {
  final String email;
  final String? profileImageUrl;

  AnalyticsProfileModel({
    required this.email,
    this.profileImageUrl,
  });

  factory AnalyticsProfileModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsProfileModel(
      email: json['email'] ?? '',
      profileImageUrl: json['profileImageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'profileImageUrl': profileImageUrl,
    };
  }
}
