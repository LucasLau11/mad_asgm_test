import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/analytics_app_state.dart';

class AnalyticsPersonalSettingsView extends StatelessWidget {
  const AnalyticsPersonalSettingsView({super.key});

  final List<String> _genderOptions = const ['Male', 'Female', 'Other'];

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalyticsAppState>(
      builder: (context, appState, _) {
        final isDark = appState.darkMode;
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100;
        final textColor = isDark ? Colors.white : Colors.black87;

        final weightOptions = appState.weightOptions;
        final heightOptions = appState.heightOptions;

        final currentWeight = weightOptions.contains(appState.weight)
            ? appState.weight
            : appState.defaultWeight;
        final currentHeight = heightOptions.contains(appState.height)
            ? appState.height
            : appState.defaultHeight;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black,
            elevation: 0,
            leading: const BackButton(),
            title: const Text('Personal Settings'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                _toggleCard('GPS Tracking', appState.gpsTracking, cardColor, textColor,
                        (v) => appState.setGpsTracking(v)),
                const SizedBox(height: 12),
                _toggleCard('Heart Rate Alert', appState.heartRateAlert, cardColor, textColor,
                        (v) => appState.setHeartRateAlert(v)),
                const SizedBox(height: 12),
                _toggleCard('Auto-Detect Workout', appState.autoDetectWorkout, cardColor, textColor,
                        (v) => appState.setAutoDetectWorkout(v)),
                const SizedBox(height: 12),
                _card(
                  cardColor: cardColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Username : ${appState.username}',
                          style: TextStyle(fontSize: 15, color: textColor)),
                      OutlinedButton(
                        onPressed: () => _showChangeUsernameDialog(context, appState, isDark),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          side: BorderSide(
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                          foregroundColor: textColor,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Change', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _dropdownCard('Weight (${appState.isMetric ? "kg" : "lbs"})', currentWeight,
                    weightOptions, cardColor, textColor, (v) => appState.setWeight(v!)),
                const SizedBox(height: 12),
                _dropdownCard('Height (${appState.isMetric ? "cm" : "ft"})', currentHeight,
                    heightOptions, cardColor, textColor, (v) => appState.setHeight(v!)),
                const SizedBox(height: 12),
                _dropdownCard('Gender', appState.gender, _genderOptions, cardColor, textColor,
                        (v) => appState.setGender(v!)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card({required Widget child, required Color cardColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10)),
      child: child,
    );
  }

  Widget _toggleCard(String label, bool value, Color cardColor, Color textColor,
      ValueChanged<bool> onChanged) {
    return _card(
      cardColor: cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: textColor)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _dropdownCard(String label, String value, List<String> options, Color cardColor,
      Color textColor, ValueChanged<String?> onChanged) {
    return _card(
      cardColor: cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: textColor)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: cardColor,
              style: TextStyle(fontSize: 14, color: textColor),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangeUsernameDialog(BuildContext context, AnalyticsAppState appState, bool isDark) {
    final controller = TextEditingController(text: appState.username);
    String? errorText;

    String? validate(String val) {
      final trimmed = val.trim();
      if (trimmed.isEmpty) return 'Username cannot be empty.';
      if (trimmed.length < 3) return 'Must be at least 3 characters.';
      if (trimmed.length > 20) return 'Must be 20 characters or fewer.';
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
        return 'Only letters, numbers, and underscores allowed.';
      }
      return null;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Username'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'New username',
                  errorText: errorText,
                  helperText: 'Letters, numbers, underscores. 3–20 chars.',
                  helperMaxLines: 2,
                ),
                onChanged: (val) => setDialogState(() => errorText = validate(val)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final error = validate(controller.text);
                if (error != null) {
                  setDialogState(() => errorText = error);
                  return;
                }
                appState.setUsername(controller.text);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}