
import 'package:flutter/material.dart';
import 'database_service.dart';
import 'models/health_record_model.dart';

class HealthMonitorPage extends StatefulWidget {
  const HealthMonitorPage({super.key});

  @override
  State<HealthMonitorPage> createState() => _HealthMonitorPageState();
}

class _HealthMonitorPageState extends State<HealthMonitorPage> {
  final dbService = DatabaseService();

  int _latestHeartRate = 0;
  double _todayWaterTotal = 0.0;
  double _latestWeight = 0.0;
  final double _waterGoal = 2400.0;

  @override
  void initState(){
    super.initState();
    _loadTodaySummary();
  }

  // load today record & extract values for the display cards
  void _loadTodaySummary() async{
    List<HealthRecordModel> todayRecords = await dbService.getTodayRecords();

    int heartRate = 0;
    double waterTotal = 0;
    double weight = 0.0;
    
    for (var record in todayRecords){
      // order from newest first
      if(record.heartRate > 0 && heartRate == 0){
        heartRate = record.heartRate;
      }
      if(record.weight > 0 && weight == 0){
        weight = record.weight;
      }
      
      // sum of water total
      waterTotal += record.waterIntake;
    }
    
    setState(() {
      _latestHeartRate = heartRate;
      _todayWaterTotal = waterTotal;
      _latestWeight = weight;
    });
  }
  
  // called to refresh page when coming back from other pages
  void _refreshPage(){
    _loadTodaySummary();
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    double waterProgress = (_todayWaterTotal / _waterGoal).clamp(0.0, 1.0);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      
      body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header
                const Text(
                  'Health Monitor',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold
                  ),
                ),
                
                Text(
                  _getTodayDate(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // heart rate banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBBDEFB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 22,
                      ),

                      const Text(
                        'Heart Rate',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const Expanded(child: SizedBox()),
                      Text(
                        _latestHeartRate == 0 ? '-- bpm' : '&_latestHeartRate bpm',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // water intake & weight cards
                Row(
                  children: [
                    // water intake
                    Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
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
                              const Text(
                                'Water intake',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                _todayWaterTotal == 0 ? '0 L' : '${(_todayWaterTotal / 1000).toStringAsFixed(1)} L',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 8),

                              LinearProgressIndicator(
                                value: waterProgress,
                                backgroundColor: const Color(0xFFE8EAF6),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9FA8DA)),
                                borderRadius: BorderRadius.circular(4),
                                minHeight: 6,
                              ),

                              const SizedBox(height: 6),

                              Text(
                                '${(waterProgress * 100).toInt()}% of ${(_waterGoal / 1000).toStringAsFixed(1)}L goal',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey
                                ),
                              ),
                            ],
                          ),
                        ),
                    ),

                    const SizedBox(width: 12),

                    // weight Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                            const Text(
                                'Weight',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey
                                )
                            ),

                            const SizedBox(height: 6),

                            Text(
                              _latestWeight == 0
                                  ? '-- kg'
                                  : '${_latestWeight.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold
                              ),
                            ),

                            const SizedBox(height: 6),

                            const Text(
                              'Latest log',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // quick log
                const Text(
                  'Quick Log',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    // heart rate
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Placeholder(), // TODO: Replace: HeartRatePage()
                            ),
                          );
                          _refreshPage();
                        },

                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFCDD2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                  Icons.favorite,
                                  color: Colors.red,
                                  size: 24
                              ),

                              SizedBox(height: 6),

                              Text(
                                'Heart Rate',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500
                                ),
                              ),
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
                              builder: (context) => const Placeholder(), // TODO: Replace: WaterIntakePage()
                            ),
                          );
                          _refreshPage();
                        },

                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EAF6),
                            borderRadius: BorderRadius.circular(14),
                          ),

                          child: const Column(
                            children: [
                              Icon(
                                  Icons.water_drop,
                                  color: Color(0xFF9FA8DA),
                                  size: 24
                              ),

                              SizedBox(height: 6),

                              Text(
                                'Water',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF9FA8DA),
                                    fontWeight: FontWeight.w500
                                ),
                              ),
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
                              builder: (context) => const Placeholder(), // TODO: Replace: WeightLogPage()
                            ),
                          );
                          _refreshPage();
                        },

                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(14),
                          ),

                          child: const Column(
                            children: [
                              Icon(
                                  Icons.monitor_weight_outlined,
                                  color: Colors.green,
                                  size: 24
                              ),

                              SizedBox(height: 6),

                              Text(
                                'Weight',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  ],
                ),

                const SizedBox(height: 20),

                // today log
                const Text(
                  "Today's Log",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600
                  ),
                ),

                const SizedBox(height: 12),

                FutureBuilder(
                  future: dbService.getTodayRecords(),
                  builder: (context, snapshot) {

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                          itemCount: snapshot.data!.length,
                          separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                          itemBuilder: (context, index) {
                            HealthRecordModel record = snapshot.data![index];
                            return _buildLogItem(record);
                          },
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'No records logged today.',
                          style: TextStyle(
                              color: Colors.grey
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
      ),

      // navbar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF9FA8DA),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          // TODO: Handle navigation to other main tabs
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workout'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'Activity'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'Health'),
        ],
      ),
    );
  }

  // Each row in Today's Log — tapping it goes to the edit page for that record
  Widget _buildLogItem(HealthRecordModel record) {
    String title = '';
    String value = '';
    String time = _formatTime(record.createdOn);
    Color dotColor = Colors.grey;

    if (record.heartRate > 0) {
      title = 'Heart Rate';
      value = '${record.heartRate} bpm';
      dotColor = Colors.red;
    } else if (record.waterIntake > 0) {
      title = 'Water Intake';
      value = '${record.waterIntake.toInt()} ml';
      dotColor = const Color(0xFF9FA8DA);
    } else if (record.weight > 0) {
      title = 'Weight';
      value = '${record.weight.toStringAsFixed(1)} kg';
      dotColor = Colors.green;
    }

    return InkWell(
      onTap: () async {
        // go to the edit page based on what type of record
        if (record.heartRate > 0) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const Placeholder(), // TODO: Replace: HeartRateEditPage(record: record)
            ),
          );
        } else if (record.waterIntake > 0) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const Placeholder(), // TODO Replace: WaterIntakeEditPage(record: record)
            ),
          );
        } else if (record.weight > 0) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const Placeholder(), // TODO Replace: WeightEditPage(record: record)
            ),
          );
        }
        _refreshPage();
      },

      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12
        ),

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

            // title and time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600
                      )
                  ),

                  Text(
                      time,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey
                      )
                  ),
                ],
              ),
            ),

            // value
            Text(
                value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600
                )
            ),

            const SizedBox(width: 4),

            // hint to show it's tappable
            const Icon(
                Icons.chevron_right,
                color: Colors.grey,
                size: 18
            ),

          ],
        ),
      ),
    );
  }

  // format "2026-03-01 08:30:00" to "08:30 AM"
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
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}