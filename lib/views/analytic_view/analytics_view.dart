import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../../models/analytic_model/analytics_app_state.dart';
import '../../models/analytic_model/analytics_goal_model.dart';
import 'analytics_add_goal_view.dart';
import 'analytics_profile_view.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  String _selectedPeriod = 'Daily';
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly'];

  @override
  void initState() {
    super.initState();
    // Data was already loaded in loadFromStorage(). We trigger a refresh
    // here so switching back to the Analytics tab always shows fresh data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsAppState>().refreshAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalyticsAppState>(
      builder: (context, appState, _) {
        final controller       = appState.analyticsController;
        final isDark           = appState.darkMode;
        final cardColor        = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100;
        final textColor        = isDark ? Colors.white : Colors.black87;
        final subtitleColor    = isDark ? Colors.white54 : Colors.black45;

        final dataPoints   = controller.calorieData[_selectedPeriod] ?? [];
        final currentKcal  = dataPoints.isNotEmpty ? dataPoints.last.toInt() : 0;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Text('Analytics', style: TextStyle(color: textColor)),
            actions: [
              // Manual refresh button
              if (appState.analyticsLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: Icon(Icons.refresh, color: textColor),
                  onPressed: () => appState.refreshAnalytics(),
                  tooltip: 'Refresh data',
                ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsProfileView()),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(Icons.person_outline, color: textColor),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => appState.refreshAnalytics(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period selector
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _periods.map((p) {
                          final selected = p == _selectedPeriod;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedPeriod = p),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFD0C8F8) : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                p,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  color: selected ? const Color(0xFF5B4FCF) : subtitleColor,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Kcal display
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '$currentKcal',
                          style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text('Kcal', style: TextStyle(fontSize: 13, color: subtitleColor)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Line chart — shows skeleton bars when loading
                  SizedBox(
                    height: 120,
                    child: appState.analyticsLoading
                        ? _buildChartSkeleton(isDark)
                        : CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _LineChartPainter(dataPoints),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Active Calories row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active Calories',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                      Text(controller.daysSummary,
                          style: TextStyle(fontSize: 13, color: subtitleColor)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem(Icons.favorite_outline,
                          '${controller.last7DaysKcal} Kcal', 'Last 7 days', textColor, subtitleColor),
                      _statItem(Icons.water_drop_outlined,
                          controller.allTimeKcal >= 1000
                              ? '${(controller.allTimeKcal / 1000).toStringAsFixed(1)}k Kcal'
                              : '${controller.allTimeKcal} Kcal',
                          'All Time', textColor, subtitleColor),
                      _statItem(Icons.bolt_outlined,
                          '${controller.averageKcal} Kcal', 'Average', textColor, subtitleColor),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // AI Recommendation card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0C8F8).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF5B4FCF).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF5B4FCF)),
                            const SizedBox(width: 6),
                            Text('Today\'s Recommendation',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF5B4FCF))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        appState.analyticsLoading
                            ? _buildTextSkeleton(isDark)
                            : Text(
                          controller.generateRecommendation(goals: appState.goals),
                          style: TextStyle(fontSize: 13, color: textColor, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Goals section header
                  Text('Goals',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 12),

                  // Goal cards
                  ...appState.goals.map((goal) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _goalCard(goal, cardColor, textColor, subtitleColor, appState),
                  )),

                  // Add more goals
                  _addGoalCard(cardColor, textColor),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartSkeleton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildTextSkeleton(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 12,
          width: 200,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _statItem(IconData icon, String value, String label,
      Color textColor, Color subtitleColor) {
    return Column(
      children: [
        Icon(icon, size: 20, color: subtitleColor),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
        Text(label, style: TextStyle(fontSize: 11, color: subtitleColor)),
      ],
    );
  }

  Widget _goalCard(GoalModel goal, Color cardColor, Color textColor,
      Color subtitleColor, AnalyticsAppState appState) {
    final hasMismatch = appState.displayGoalType(goal.goalType) != goal.goalType;
    final displayType = appState.displayGoalType(goal.goalType);
    final targetInt   = int.tryParse(goal.target) ?? 1;
    final progress    = (goal.progress / targetInt).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: hasMismatch
            ? Border.all(color: Colors.orange.shade300, width: 1.5)
            : null,
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${goal.progress}/${goal.target} $displayType',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor),
              ),
              const SizedBox(height: 6),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: textColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? Colors.green : const Color(0xFF5B4FCF),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(goal.deadline, style: TextStyle(fontSize: 12, color: subtitleColor)),
              if (goal.reason.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  goal.reason,
                  style: TextStyle(fontSize: 12, color: subtitleColor, fontStyle: FontStyle.italic),
                ),
              ],
              if (hasMismatch) ...[
                const SizedBox(height: 6),
                Text(
                  'Goal was set in a different unit system. Tap edit to update it.',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700, height: 1.4),
                ),
              ],
              const SizedBox(height: 28), // space for bottom buttons
            ],
          ),

          // Edit button
          Positioned(
            left: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddGoalView(existingGoal: goal)),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF5B4FCF),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: const Text('Edit',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ),
          ),

          // Dismiss button
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => _confirmDismiss(context, goal, appState),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(10),
                    topLeft: Radius.circular(10),
                  ),
                ),
                child: const Text('Dismiss',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDismiss(BuildContext context, GoalModel goal, AnalyticsAppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Goal?'),
        content: Text(
            'Are you sure you want to remove "${goal.progress}/${goal.target} ${goal.goalType}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.removeGoal(goal.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _addGoalCard(Color cardColor, Color textColor) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddGoalView())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10)),
        child: Center(
          child: Text('Add more goals +',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor)),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> dataPoints;
  _LineChartPainter(this.dataPoints);

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    // Show a flat zero line when no data has been recorded yet
    final hasData = dataPoints.any((v) => v > 0);
    final drawPoints = hasData ? dataPoints : dataPoints;

    final minVal = hasData ? drawPoints.reduce(min) : 0.0;
    final maxVal = hasData ? drawPoints.reduce(max) : 1.0;
    final range  = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final paint = Paint()
      ..color = const Color(0xFFFF6B8A)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFF6B8A).withOpacity(0.2),
          const Color(0xFFFF6B8A).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final points = List.generate(drawPoints.length, (i) {
      final x = i * size.width / (drawPoints.length - 1);
      final y = hasData
          ? size.height -
          ((drawPoints[i] - minVal) / range) * size.height * 0.8 -
          size.height * 0.1
          : size.height * 0.9; // flat line at bottom when no data
      return Offset(x, y);
    });

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i + 1].dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i + 1].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
    }
    canvas.drawPath(linePath, paint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.dataPoints != dataPoints;
}