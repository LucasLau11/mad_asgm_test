import '../models/analytic_model/analytics_goal_model.dart';

class AnalyticsController {
  final List<Map<String, dynamic>> _workoutHistory = [
    {'exercise': 'Running', 'detail': '1 km', 'date': 'Yesterday'},
    {'exercise': 'Squats', 'detail': '5 sets', 'date': 'Yesterday'},
    {'exercise': 'Cycling', 'detail': '5 km', 'date': '2 days ago'},
  ];

  Map<String, List<double>> get calorieData => {
    'Daily': [200, 350, 280, 420, 310, 390, 260],
    'Weekly': [1800, 2100, 1950, 2300, 2050, 1700, 2400],
    'Monthly': [7200, 8100, 7600, 8900],
  };

  int get last7DaysKcal => 246;
  int get allTimeKcal => 84000;
  int get averageKcal => 72;

  String generateRecommendation() {
    if (_workoutHistory.isEmpty) return 'Start logging workouts to get recommendations!';

    final recent = _workoutHistory
        .where((w) => w['date'] == 'Yesterday')
        .map((w) => '${w['detail']} of ${w['exercise']}')
        .join(' and ');

    return 'Yesterday you did $recent. '
        'Today try focusing on upper body — consider weight lifting or push-ups to balance your routine.';
  }

  String get daysSummary => '7 days';
}
