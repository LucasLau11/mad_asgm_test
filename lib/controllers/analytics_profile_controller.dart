import '../models/analytic_model/analytics_profile_model.dart';
import '../services/database/heart_rate_database_service.dart' as shared_db;

class AnalyticsProfileController {
  Future<AnalyticsProfileModel> fetchUserProfile() async {
    final user = shared_db.DatabaseService.currentUser;
    return AnalyticsProfileModel(
      email: user?.email ?? '',
      profileImageUrl: null,
    );
  }

  Future<void> logout() async {
    // Session is cleared by DatabaseService().logoutUser() in profile_view.
    // Add any extra cleanup (tokens, caches) here if needed.
  }
}