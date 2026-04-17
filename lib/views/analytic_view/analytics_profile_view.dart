import 'package:flutter/material.dart';
import 'package:mad_asgm/views/login_screen.dart';
import 'package:provider/provider.dart';
import '../../services/database/heart_rate_database_service.dart';
import '../../models/analytic_model/analytics_app_state.dart';
import '../../models/analytic_model/analytics_profile_model.dart';
import '../../controllers/analytics_profile_controller.dart';
import 'analytics_settings_view.dart';
import 'analytics_personal_settings_view.dart';
import 'analytics_help_view.dart';

class AnalyticsProfileView extends StatefulWidget {
  const AnalyticsProfileView({super.key});

  @override
  State<AnalyticsProfileView> createState() => _AnalyticsProfileViewState();
}

class _AnalyticsProfileViewState extends State<AnalyticsProfileView> {
  final AnalyticsProfileController _controller = AnalyticsProfileController();
  AnalyticsProfileModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await _controller.fetchUserProfile();
    setState(() {
      _user = user;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalyticsAppState>(
      builder: (context, appState, _) {
        final isDark = appState.darkMode;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black,
            elevation: 0,
            leading: const BackButton(),
            title: const Text('User Profile'),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(appState),
        );
      },
    );
  }

  Widget _buildBody(AnalyticsAppState appState) {
    final isDark = appState.darkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 48,
            backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            backgroundImage: _user?.profileImageUrl != null
                ? NetworkImage(_user!.profileImageUrl!)
                : null,
            child: _user?.profileImageUrl == null
                ? Icon(Icons.person,
                size: 48, color: isDark ? Colors.white54 : Colors.black54)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            appState.username,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          _menuButton('Settings', isDark, onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AnalyticsSettingsView()));
          }),
          const SizedBox(height: 12),
          _menuButton('Personal Settings', isDark, onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AnalyticsPersonalSettingsView()));
          }),
          const SizedBox(height: 12),
          _menuButton('Help', isDark, onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AnalyticsHelpView()));
          }),
          const SizedBox(height: 12),
          _menuButton('Logout', isDark, onTap: () async {
            await _controller.logout();
            DatabaseService().logoutUser();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false, // removes all previous routes so back button won't work
            );
          }),
        ],
      ),
    );
  }

  Widget _menuButton(String label, bool isDark, {required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
