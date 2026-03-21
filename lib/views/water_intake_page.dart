import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mad_asgm/views/water_intake_edit_page.dart';
import '../controllers/database_service.dart';
import '../models/water_intake_model.dart';

class WaterIntakePage extends StatefulWidget {
  const WaterIntakePage({super.key});

  @override
  State<WaterIntakePage> createState() => _WaterIntakePageState();
}

class _WaterIntakePageState extends State<WaterIntakePage> {
  final dbService = DatabaseService();

  final amountController = TextEditingController();
  final noteController = TextEditingController();

  // Selected beverage type from dropdown
  String _selectedBeverageType = 'Water';

  // List of beverage options for the dropdown
  final List<String> _beverageTypes = ['Water', 'Coffee', 'Tea', 'Juice', 'Other'];

  // Daily goal in ml
  final double _dailyGoal = 2400.0;

  @override
  void dispose() {
    super.dispose();
    amountController.dispose();
    noteController.dispose();
  }

  // Log a new water intake record
  void _logWaterIntake() async {
    // Validate amount field
    if (amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount.')),
      );
      return;
    }

    double amount = double.parse(amountController.text);

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than 0.')),
      );
      return;
    }

    // Build time string e.g. "10:00 AM"
    final now = DateTime.now();
    String time = _formatTime(now);

    WaterIntakeModel newRecord = WaterIntakeModel(
      id: 0,
      amountMl: amount,
      beverageType: _selectedBeverageType,
      time: time,
      note: noteController.text,
      createdOn: '',
    );

    await dbService.insertWaterRecord(newRecord);

    // Clear inputs
    amountController.clear();
    noteController.clear();
    setState(() {
      _selectedBeverageType = 'Water';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Water intake logged!')),
    );
  }

  // Calculate total ml logged today
  Future<double> _getTodayTotal() async {
    List<WaterIntakeModel> records = await dbService.getTodayWaterRecords();
    double total = 0;
    for (var r in records) {
      total += r.amountMl;
    }
    return total;
  }

  // Format DateTime to "10:00 AM"
  String _formatTime(DateTime dt) {
    int hour = dt.hour;
    int minute = dt.minute;
    String period = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
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
          'Water Intake',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ---- Daily Goal Progress Card ----
            FutureBuilder<double>(
              future: _getTodayTotal(),
              builder: (context, snapshot) {
                double total = snapshot.data ?? 0.0;
                double progress = (total / _dailyGoal).clamp(0.0, 1.0);
                double remaining = (_dailyGoal - total).clamp(0.0, _dailyGoal);

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
                    children: [
                      const Text(
                        'Daily Goal Progress',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 16),

                      // Circular progress indicator
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              backgroundColor: const Color(0xFFE8EAF6),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9FA8DA)),
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '${(total / 1000).toStringAsFixed(1)}L',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF9FA8DA),
                                ),
                              ),
                              Text(
                                'of ${(_dailyGoal / 1000).toStringAsFixed(1)}L',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text(
                        '${(remaining / 1000).toStringAsFixed(1)}L remaining to reach your goal',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ---- Log Custom Amount Card ----
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
                    'Log Custom Amount',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 12),

                  // Amount field
                  const Text('Amount (ML)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'e.g. 350',
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
                        borderSide: const BorderSide(color: Color(0xFF9FA8DA)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Beverage Type dropdown
                  const Text('Beverage Type', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedBeverageType,
                    items: _beverageTypes.map((String type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _selectedBeverageType = value!;
                      });
                    },
                    decoration: InputDecoration(
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
                        borderSide: const BorderSide(color: Color(0xFF9FA8DA)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Note field
                  const Text('Note (Optional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: 'e.g. Morning',
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
                        borderSide: const BorderSide(color: Color(0xFF9FA8DA)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Log Water Intake Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        _logWaterIntake();
                        setState(() {}); // Refresh the Today's Log list below
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9FA8DA),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Log Water Intake',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ---- Today's Log List ----
            const Text(
              "Today's Log",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 12),

            FutureBuilder<List<WaterIntakeModel>>(
              future: dbService.getTodayWaterRecords(),
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
                        WaterIntakeModel record = snapshot.data![index];
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
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Each row in Today's Log — tap to go to edit page
  Widget _buildLogItem(WaterIntakeModel record) {
    return InkWell(
      onTap: () async {
        // Go to edit page, passing the record
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WaterIntakeEditPage(record: record),
          ),
        );
        setState(() {}); // Refresh list when coming back
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [

            // Colored dot
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF9FA8DA).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.circle, color: Color(0xFF9FA8DA), size: 14),
            ),

            const SizedBox(width: 12),

            // Time and note
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.time,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    record.note.isEmpty ? record.beverageType : record.note,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              '${record.amountMl.toInt()} ml',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),

            const SizedBox(width: 4),

            // Arrow to show it's tappable
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),

          ],
        ),
      ),
    );
  }
}