
import 'package:flutter/material.dart';

import '../controllers/database_service.dart';
import '../models/heart_rate_model.dart';

class HeartRateHistoryPage extends StatefulWidget {
  const HeartRateHistoryPage({super.key});

  @override
  State<HeartRateHistoryPage> createState() => _HeartRateHistoryPageState();
}

class _HeartRateHistoryPageState extends State<HeartRateHistoryPage> {
  final dbService = DatabaseService();

  // Toggle between week and month view on the chart
  bool _showWeekly = true;

  // Show delete confirmation bottom sheet
  void _showDeleteBottomSheet(HeartRateModel record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 24),

              // Delete icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
              ),

              const SizedBox(height: 16),

              const Text(
                'Delete Record?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 8),

              Text(
                'You\'re about to delete the heart rate record at ${_formatTime(record.createdOn)}. This action cannot be undone.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),

              const SizedBox(height: 20),

              // Record preview
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Heart Rate - ${_formatTime(record.createdOn)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${record.bpm} bpm - ${record.status}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9FA8DA),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Yes, Delete button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await dbService.deleteHeartRateRecord(record.id);
                    Navigator.pop(context); // close bottom sheet
                    setState(() {}); // refresh list
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF9A9A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Yes, Delete',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Get status badge color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Low':
        return Colors.blue;
      case 'Normal':
        return Colors.green;
      case 'Elevated':
        return Colors.orange;
      case 'High':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Format "2026-03-01 08:30:00" -> "08:32 AM"
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

  // Format "2026-03-01 08:30:00" -> "Today - Mar 1" or "Feb 28"
  String _formatDateHeader(String dateTime) {
    if (dateTime.isEmpty) return '';
    try {
      DateTime dt = DateTime.parse(dateTime);
      DateTime now = DateTime.now();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      bool isToday = dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day;
      if (isToday) return 'Today - ${months[dt.month - 1]} ${dt.day}';
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (e) {
      return dateTime;
    }
  }

  // Build the simple weekly chart using bar-like dots
  Widget _buildWeeklyChart(List<HeartRateModel> allRecords) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();

    // Get average BPM for each of the last 7 days
    List<double> averages = List.generate(7, (i) {
      DateTime day = now.subtract(Duration(days: 6 - i));
      List<HeartRateModel> dayRecords = allRecords.where((r) {
        if (r.createdOn.isEmpty) return false;
        DateTime dt = DateTime.parse(r.createdOn);
        return dt.year == day.year &&
            dt.month == day.month &&
            dt.day == day.day;
      }).toList();

      if (dayRecords.isEmpty) return 0.0;
      return dayRecords.map((r) => r.bpm).reduce((a, b) => a + b) /
          dayRecords.length;
    });

    double maxBpm = averages.reduce((a, b) => a > b ? a : b);
    if (maxBpm == 0) maxBpm = 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          // Title + Week/Month toggle
          Row(
            children: [
              const Text(
                'Weekly Average',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Expanded(child: SizedBox()),
              // Week toggle
              GestureDetector(
                onTap: () => setState(() => _showWeekly = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _showWeekly ? const Color(0xFF9FA8DA) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Week',
                    style: TextStyle(
                      fontSize: 12,
                      color: _showWeekly ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              // Month toggle
              GestureDetector(
                onTap: () => setState(() => _showWeekly = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: !_showWeekly ? const Color(0xFF9FA8DA) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Month',
                    style: TextStyle(
                      fontSize: 12,
                      color: !_showWeekly ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Simple bar chart
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (i) {
                double avg = averages[i];
                double heightPercent = avg == 0 ? 0.05 : avg / maxBpm;
                bool isToday = i == 6;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 28,
                      height: 60 * heightPercent,
                      decoration: BoxDecoration(
                        color: isToday
                            ? Colors.red
                            : Colors.red.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      days[i],
                      style: TextStyle(
                        fontSize: 10,
                        color: isToday ? Colors.red : Colors.grey,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Heart Rate History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        ),
      ),

      body: FutureBuilder<List<HeartRateModel>>(
        future: dbService.getHeartRateRecords(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<HeartRateModel> allRecords = snapshot.data ?? [];

          // Get today's records from the full list
          DateTime now = DateTime.now();
          List<HeartRateModel> todayRecords = allRecords.where((r) {
            if (r.createdOn.isEmpty) return false;
            DateTime dt = DateTime.parse(r.createdOn);
            return dt.year == now.year &&
                dt.month == now.month &&
                dt.day == now.day;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ---- Weekly Chart ----
                _buildWeeklyChart(allRecords),

                const SizedBox(height: 20),

                // ---- Today's Records ----
                Text(
                  _formatDateHeader(
                    todayRecords.isNotEmpty ? todayRecords.first.createdOn : '',
                  ),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

                todayRecords.isEmpty
                    ? Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'No heart rate records today.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
                    : Container(
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
                    itemCount: todayRecords.length,
                    separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    itemBuilder: (context, index) {
                      HeartRateModel record = todayRecords[index];
                      return _buildLogItem(record);
                    },
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // Each row in today's list
  Widget _buildLogItem(HeartRateModel record) {
    Color statusColor = _getStatusColor(record.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [

          // Red dot
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.circle, color: Colors.red, size: 14),
          ),

          const SizedBox(width: 12),

          // Time
          Expanded(
            child: Text(
              _formatTime(record.createdOn),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),

          // BPM value
          Text(
            '${record.bpm} bpm',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),

          const SizedBox(width: 8),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              record.status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Delete button
          GestureDetector(
            onTap: () => _showDeleteBottomSheet(record),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                decoration: TextDecoration.underline,
              ),
            ),
          ),

        ],
      ),
    );
  }
}