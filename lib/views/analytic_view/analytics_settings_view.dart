import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/analytic_model/analytics_app_state.dart';

class AnalyticsSettingsView extends StatelessWidget {
  const AnalyticsSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalyticsAppState>(
      builder: (context, appState, _) {
        final isDark = appState.darkMode;
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100;
        final textColor = isDark ? Colors.white : Colors.black87;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black,
            elevation: 0,
            leading: const BackButton(),
            title: const Text('Settings'),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                _settingsCard(
                  cardColor: cardColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Measurement Units',
                          style: TextStyle(fontSize: 15, color: textColor)),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: appState.measurementUnit,
                          dropdownColor: cardColor,
                          style: TextStyle(fontSize: 14, color: textColor),
                          items: ['Metric', 'Imperial']
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (val) => appState.setMeasurementUnit(val!),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _settingsCard(
                  cardColor: cardColor,
                  child: _toggleRow('Notifications', appState.notifications, textColor,
                          (v) => appState.setNotifications(v)),
                ),
                const SizedBox(height: 12),
                _settingsCard(
                  cardColor: cardColor,
                  child: _toggleRow('Workout Reminder', appState.workoutReminder, textColor,
                          (v) => appState.setWorkoutReminder(v)),
                ),
                const SizedBox(height: 12),
                _settingsCard(
                  cardColor: cardColor,
                  child: _toggleRow('Dark Mode', appState.darkMode, textColor,
                          (v) => appState.setDarkMode(v)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _settingsCard({required Widget child, required Color cardColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10)),
      child: child,
    );
  }

  Widget _toggleRow(String label, bool value, Color textColor, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 15, color: textColor)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}