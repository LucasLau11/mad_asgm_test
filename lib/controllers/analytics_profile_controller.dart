import '../models/analytics_profile_model.dart';

class AnalyticsProfileController {
  Future<AnalyticsProfileModel> fetchUserProfile() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return AnalyticsProfileModel(
      email: 'johndoe@example.com',
      profileImageUrl: null,
    );
  }

  Future<void> logout() async {
    // TODO: clear session/token, navigate to login
  }
}
