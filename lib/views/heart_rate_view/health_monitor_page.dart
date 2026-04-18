import 'package:flutter/material.dart';
import 'package:mad_asgm/models/heart_rate_model/water_intake_model.dart';
import 'package:mad_asgm/views/heart_rate_view/water_intake_edit_page.dart';
import 'package:mad_asgm/views/heart_rate_view/water_intake_page.dart';
import 'package:mad_asgm/views/heart_rate_view/weight_log_edit_page.dart';
import 'package:mad_asgm/views/heart_rate_view/weight_log_page.dart';
import 'package:provider/provider.dart';
import '../../models/analytic_model/analytics_app_state.dart';
import '../../services/database/heart_rate_database_service.dart';
import '../../models/heart_rate_model/heart_rate_model.dart';
import '../../models/heart_rate_model/weight_model.dart';
import 'heart_rate_page.dart';

class HealthMonitorPage extends StatefulWidget {
  const HealthMonitorPage({super.key});

  @override
  State<HealthMonitorPage> createState() => _HealthMonitorPageState();
}

class _HealthMonitorPageState extends State<HealthMonitorPage> {
  final dbService = DatabaseService();

  int _latestHeartRate = 0;
  double _todayWaterTotal = 0.0;
  double _latestWeightKg = 0.0;
  double _previousWeightKg = 0.0;
  double _waterGoal = 2400.0;

  // hold today's records for the today log
  List<HeartRateModel> _todayHeartRecords = [];
  List<WaterIntakeModel> _todayWaterRecords = [];
  List<WeightModel> _todayWeightRecords = [];

  @override
  void initState() {
    super.initState();
    _loadTodaySummary();
  }

  void _loadTodaySummary() async {
    List<HeartRateModel> heartRecords = await dbService.getTodayHeartRateRecords();
    List<WaterIntakeModel> waterRecords = await dbService.getTodayWaterRecords();
    List<WeightModel> weightRecords = await dbService.getTodayWeightRecords();

    int heartRate = heartRecords.isNotEmpty ? heartRecords.first.bpm : 0;

    double waterTotal = 0;
    for (var r in waterRecords) {
      waterTotal += r.amountMl;
    }

    double weightKg = weightRecords.isNotEmpty ? weightRecords.first.weightKg : 0.0;
    double prevWeightKg = weightRecords.length >= 2 ? weightRecords[1].weightKg : 0.0;

    setState(() {
      _latestHeartRate = heartRate;
      _todayWaterTotal = waterTotal;
      _latestWeightKg = weightKg;
      _previousWeightKg = prevWeightKg;
      _todayHeartRecords = heartRecords;
      _todayWaterRecords = waterRecords;
      _todayWeightRecords = weightRecords;
    });
  }

  void _refreshPage() {
    _loadTodaySummary();
    setState(() {});
  }

  double _toDisplayWeight(double kg, bool isMetric) =>
      isMetric ? kg : kg * 2.20462;

  String _formatDisplayWeight(double kg, bool isMetric) {
    if (kg == 0) return isMetric ? '-- kg' : '-- lbs';
    final val = _toDisplayWeight(kg, isMetric);
    return isMetric
        ? '${val.toStringAsFixed(1)} kg'
        : '${val.toStringAsFixed(1)} lbs';
  }

  String _weightUnit(bool isMetric) => isMetric ? 'kg' : 'lbs';


  List<Map<String, dynamic>> _getCombinedTodayLog() {
    List<Map<String, dynamic>> combined = [];
    for (var r in _todayHeartRecords) {
      combined.add({'type': 'heart', 'record': r, 'createdOn': r.createdOn});
    }
    for (var r in _todayWaterRecords) {
      combined.add({'type': 'water', 'record': r, 'createdOn': r.createdOn});
    }
    for (var r in _todayWeightRecords) {
      combined.add({'type': 'weight', 'record': r, 'createdOn': r.createdOn});
    }
    combined.sort((a, b) => b['createdOn'].compareTo(a['createdOn']));
    return combined;
  }

  @override
  Widget build(BuildContext context) {
    // Read isMetric
    final isMetric = context.watch<AnalyticsAppState>().isMetric;

    double waterProgress = (_todayWaterTotal / _waterGoal).clamp(0.0, 1.0);
    List<Map<String, dynamic>> combinedLog = _getCombinedTodayLog();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Text(
                'Health Monitor',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface
                ),
              ),
              Text(
                _getTodayDate(),
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant
                ),
              ),

              const SizedBox(height: 20),

              // heart rate banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Heart Rate',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                    Text(
                      _latestHeartRate == 0 ? '-- bpm' : '$_latestHeartRate bpm',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // water intake & weight cards
              IntrinsicHeight(
                child: Row(
                  children: [
                    // water intake card
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final TextEditingController goalController =
                          TextEditingController(
                              text: (_waterGoal / 1000).toStringAsFixed(1));
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: Text('Set Water Goal',
                                  style:
                                  TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface
                                  )),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Enter your daily water goal (L)',
                                      style: TextStyle(
                                          fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: goalController,
                                    keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      suffixText: 'L',
                                      hintText: '2.0',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(10)),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF9FA8DA), width: 2),
                                      ),
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Cancel',
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    final double? newGoal =
                                    double.tryParse(goalController.text);
                                    if (newGoal != null && newGoal > 0) {
                                      setState(
                                              () => _waterGoal = newGoal * 1000);
                                      Navigator.pop(context);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF9FA8DA),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Water intake',
                                      style: TextStyle(
                                          fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  const Spacer(),
                                  const Icon(Icons.edit,
                                      size: 12, color: Colors.grey),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _todayWaterTotal == 0
                                    ? '0 L'
                                    : '${(_todayWaterTotal / 1000).toStringAsFixed(1)} L',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: waterProgress,
                                backgroundColor: const Color(0xFFE8EAF6),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF9FA8DA)),
                                borderRadius: BorderRadius.circular(4),
                                minHeight: 6,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(waterProgress * 100).toInt()}% of ${(_waterGoal / 1000).toStringAsFixed(1)}L goal',
                                style: TextStyle(
                                    fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // weight card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weight (${_weightUnit(isMetric)})',
                              style: TextStyle(
                                  fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDisplayWeight(_latestWeightKg, isMetric),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Builder(builder: (_) {
                              if (_latestWeightKg == 0 ||
                                  _previousWeightKg == 0) {
                                return Text('Latest log',
                                    style: TextStyle(
                                        fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant));
                              }
                              final diffKg =
                                  _latestWeightKg - _previousWeightKg;
                              final diffDisplay =
                              _toDisplayWeight(diffKg.abs(), isMetric);
                              final isGain = diffKg > 0;
                              return Row(
                                children: [
                                  Icon(
                                    isGain
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 11,
                                    color:
                                    isGain ? Colors.red : Colors.green,
                                  ),
                                  Flexible(
                                    child: Text(
                                      '${diffDisplay.toStringAsFixed(1)} ${_weightUnit(isMetric)} vs previous.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                        isGain ? Colors.red : Colors.green,
                                      ),
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // quick log
              const Text('Quick Log',
                  style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              Row(
                children: [
                  // heart rate
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(context,
                            MaterialPageRoute(
                                builder: (context) => HeartRatePage()));
                        _refreshPage();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.surface
                              : Color(0xFFFFCDD2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.favorite, color: Colors.red, size: 24),
                            SizedBox(height: 6),
                            Text('Heart Rate',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // water intake
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => WaterIntakePage()));
                        _refreshPage();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.surface
                              : Color(0xFFE8EAF6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.water_drop,
                                color: Color(0xFF9FA8DA), size: 24),
                            SizedBox(height: 6),
                            Text('Water',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF9FA8DA),
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // weight
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => WeightLogPage()));
                        _refreshPage();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.surface
                              : Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.monitor_weight_outlined,
                                color: Colors.green, size: 24),
                            SizedBox(height: 6),
                            Text('Weight',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // today log
              const Text("Today's Log",
                  style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              combinedLog.isEmpty
                  ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child:  Center(
                  child: Text('No records logged today.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              )
                  : Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: combinedLog.length,
                  separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  itemBuilder: (context, index) =>
                      _buildLogItem(combinedLog[index], isMetric),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> item, bool isMetric) {
    String type = item['type'];
    String title = '';
    String value = '';
    String time = '';
    Color dotColor = Colors.grey;

    if (type == 'heart') {
      HeartRateModel record = item['record'];
      title = 'Heart Rate';
      value = '${record.bpm} bpm';
      time = _formatTime(record.createdOn);
      dotColor = Colors.red;
    } else if (type == 'water') {
      WaterIntakeModel record = item['record'];
      title = 'Water Intake';
      value = '${record.amountMl.toInt()} ml';
      time = _formatTime(record.createdOn);
      dotColor = const Color(0xFF9FA8DA);
    } else if (type == 'weight') {
      WeightModel record = item['record'];
      title = 'Weight';
      // Convert kg to display unit
      final displayVal = isMetric
          ? record.weightKg
          : record.weightKg * 2.20462;
      value =
      '${displayVal.toStringAsFixed(1)} ${isMetric ? 'kg' : 'lbs'}';
      time = _formatTime(record.createdOn);
      dotColor = Colors.green;
    }

    return InkWell(
      onTap: () async {
        if (type == 'water') {
          WaterIntakeModel record = item['record'];
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      WaterIntakeEditPage(record: record)));
        } else if (type == 'weight') {
          WeightModel record = item['record'];
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => WeightEditPage(record: record)));
        }
        _refreshPage();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: dotColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.circle, color: dotColor, size: 14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateTime) {
    if (dateTime.isEmpty) return '';
    try {
      DateTime dt = DateTime.parse(dateTime);
      int hour = dt.hour;
      int minute = dt.minute;
      String period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return dateTime;
    }
  }

  String _getTodayDate() {
    final now = DateTime.now();
    final days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday', 'Sunday'
    ];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}