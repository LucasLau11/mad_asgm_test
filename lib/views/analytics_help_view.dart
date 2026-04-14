import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analytics_app_state.dart';

class AnalyticsHelpView extends StatefulWidget {
  const AnalyticsHelpView({super.key});

  @override
  State<AnalyticsHelpView> createState() => _AnalyticsHelpViewState();
}

class _AnalyticsHelpViewState extends State<AnalyticsHelpView> {
  int _expandedIndex = -1;

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I track my workout?',
      'answer': 'Go to the Workout tab and tap "Start Workout". Choose your activity type and the app will begin tracking automatically.',
    },
    {
      'question': 'How do I set a workout reminder?',
      'answer': 'Go to Settings and enable "Workout Reminder". You can then set your preferred time from the notification settings.',
    },
    {
      'question': 'How is my heart rate monitored?',
      'answer': 'The app uses your device\'s connected health sensors. Make sure Bluetooth is enabled and your wearable is paired.',
    },
    {
      'question': 'How do I change my personal information?',
      'answer': 'Tap "Personal Settings" on your Profile page to update your username, weight, height, and gender.',
    },
    {
      'question': 'How do I contact support?',
      'answer': 'You can reach our support team at support@fitapp.com or visit our help centre at help.fitapp.com.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalyticsAppState>(
      builder: (context, appState, _) {
        final isDark = appState.darkMode;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subtitleColor = isDark ? Colors.white54 : Colors.black54;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black,
            elevation: 0,
            leading: const BackButton(),
            title: const Text('Help'),
          ),
          body: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: _faqs.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
            itemBuilder: (context, index) {
              final isExpanded = _expandedIndex == index;
              return InkWell(
                onTap: () => setState(() => _expandedIndex = isExpanded ? -1 : index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _faqs[index]['question']!,
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500, color: textColor),
                            ),
                          ),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: subtitleColor,
                          ),
                        ],
                      ),
                      if (isExpanded) ...[
                        const SizedBox(height: 8),
                        Text(
                          _faqs[index]['answer']!,
                          style: TextStyle(fontSize: 14, color: subtitleColor, height: 1.5),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
