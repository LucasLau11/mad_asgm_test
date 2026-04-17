
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mad_asgm/views/heart_rate_view/weight_log_edit_page.dart';

import '../../services/database/heart_rate_database_service.dart';
import '../../models/heart_rate_model/weight_model.dart';

class WeightLogPage extends StatefulWidget {
  const WeightLogPage({super.key});

  @override
  State<WeightLogPage> createState() => _WeightLogPageState();
}

class _WeightLogPageState extends State<WeightLogPage> {
  final dbService = DatabaseService();

  final weightController = TextEditingController();
  final noteController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    weightController.dispose();
    noteController.dispose();
  }

  // Log a new weight record
  void _logWeight() async {
    if (weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your weight.')),
      );
      return;
    }

    double weight = double.tryParse(weightController.text) ?? 0;

    if (weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight.')),
      );
      return;
    }

    WeightModel newRecord = WeightModel(
      id: 0,
      weightKg: weight,
      note: noteController.text,
      createdOn: '',
    );

    await dbService.insertWeightRecord(newRecord);

    // Clear inputs
    weightController.clear();
    noteController.clear();

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Weight logged!')),
    );
  }

  // Calculate weight change between two records
  // Returns a positive or negative number
  double? _getWeightChange(List<WeightModel> records, int index) {
    // The last item in the list has no previous record to compare
    if (index >= records.length - 1) return null;
    return records[index].weightKg - records[index + 1].weightKg;
  }

  // Format "2026-03-01 08:30:00" -> "08:30 AM"
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

  // Format "2026-03-01 08:30:00" -> "Today, Mar 1" or "Feb 28"
  String _formatDate(String dateTime) {
    if (dateTime.isEmpty) return '';
    try {
      DateTime dt = DateTime.parse(dateTime);
      DateTime now = DateTime.now();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

      bool isToday = dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day;

      if (isToday) {
        return 'Today, ${months[dt.month - 1]} ${dt.day}';
      }
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (e) {
      return dateTime;
    }
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
          'Weight Log',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        ),
      ),

      body: FutureBuilder<List<WeightModel>>(
        future: dbService.getWeightRecords(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<WeightModel> records = snapshot.data ?? [];
          WeightModel? latestRecord = records.isNotEmpty ? records.first : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ---- Current Weight Banner ----
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Current Weight',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                      Text(
                        latestRecord == null
                            ? '-- kg'
                            : '${latestRecord.weightKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ---- Log Today's Weight Card ----
                Container(
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
                      const Text(
                        "Log Today's Weight",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 12),

                      // Weight input
                      const Text('Weight', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'e.g. 70.5',
                          suffixText: 'kg',
                          suffixStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Note input
                      const Text('Note (Optional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: noteController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          hintText: 'e.g. Morning, before breakfast',
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Log Weight button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _logWeight,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Log Weight',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ---- Recent Logs List ----
                const Text(
                  'Recent Logs',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

                records.isEmpty
                    ? Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'No weight records yet.',
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
                    itemCount: records.length,
                    separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    itemBuilder: (context, index) {
                      WeightModel record = records[index];
                      double? change = _getWeightChange(records, index);
                      return _buildLogItem(record, change);
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

  // Each row in Recent Logs — tap to go to edit page
  Widget _buildLogItem(WeightModel record, double? change) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WeightEditPage(record: record),
          ),
        );
        setState(() {}); // Refresh list when coming back
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [

            // Green dot
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.circle, color: Colors.green, size: 14),
            ),

            const SizedBox(width: 12),

            // Date and time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(record.createdOn),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatTime(record.createdOn),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Weight value
            Text(
              '${record.weightKg.toStringAsFixed(1)} kg',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),

            const SizedBox(width: 8),

            // Weight change badge (e.g. +2.3 or -1.1)
            // Only show if there is a previous record to compare
            if (change != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: change > 0
                      ? Colors.red.withOpacity(0.15)
                      : Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: change > 0 ? Colors.red : Colors.green,
                  ),
                ),
              ),

            const SizedBox(width: 4),

            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),

          ],
        ),
      ),
    );
  }
}