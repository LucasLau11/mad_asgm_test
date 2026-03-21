
import 'package:flutter/material.dart';

import '../controllers/database_service.dart';
import '../models/heart_rate_model.dart';
import 'heart_rate_history_page.dart';

class HeartRatePage extends StatefulWidget {
  const HeartRatePage({super.key});

  @override
  State<HeartRatePage> createState() => _HeartRatePageState();
}

class _HeartRatePageState extends State<HeartRatePage> {
  final dbService = DatabaseService();

  // Current BPM reading — user manually enters or simulates
  int _currentBpm = 0;
  bool _isMeasuring = false;

  final bpmController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    bpmController.dispose();
  }

  // Simulate starting a measurement
  // In a real app, this would use the camera plugin to measure heart rate
  void _startMeasuring() {
    setState(() {
      _isMeasuring = true;
    });

    // Simulate a reading after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isMeasuring = false;
          // Simulate a random BPM between 60-100 for now
          // TODO: Replace with actual camera-based heart rate reading
          _currentBpm = 72 + (DateTime.now().millisecond % 30);
          bpmController.text = _currentBpm.toString();
        });
      }
    });
  }

  // Save the current reading to the database
  void _saveReading() async {
    if (bpmController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a reading first.')),
      );
      return;
    }

    int bpm = int.tryParse(bpmController.text) ?? 0;

    if (bpm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid BPM.')),
      );
      return;
    }

    String status = HeartRateModel.getStatus(bpm);

    HeartRateModel newRecord = HeartRateModel(
      id: 0,
      bpm: bpm,
      status: status,
      note: '',
      createdOn: '',
    );

    await dbService.insertHeartRateRecord(newRecord);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Heart rate saved! $bpm bpm - $status')),
    );

    setState(() {
      _currentBpm = bpm;
    });
  }

  // Get status color based on BPM
  Color _getStatusColor(int bpm) {
    if (bpm == 0) return Colors.grey;
    String status = HeartRateModel.getStatus(bpm);
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

  @override
  Widget build(BuildContext context) {
    int bpm = int.tryParse(bpmController.text) ?? 0;
    String status = bpm == 0 ? '' : HeartRateModel.getStatus(bpm);
    Color statusColor = _getStatusColor(bpm);

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
          'Heart Rate Monitor',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        actions: [
          // Button to go to history page
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HeartRateHistoryPage(),
                ),
              );
            },
            child: const Text(
              'History',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ---- Camera Sensor Box ----
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [

                  // Heart pulse animation circle
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withOpacity(0.6),
                        width: 2,
                      ),
                    ),
                  ),

                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                  ),

                  // Heart icon in the middle
                  Icon(
                    Icons.favorite,
                    color: _isMeasuring
                        ? Colors.red
                        : Colors.red.withOpacity(0.7),
                    size: 50,
                  ),

                  // "Place finger on camera" text at bottom
                  Positioned(
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.camera_alt,
                            color: Colors.white.withOpacity(0.8),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isMeasuring
                                ? 'Measuring...'
                                : 'Place finger on camera',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ---- Current Reading Card ----
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
                children: [
                  const Text(
                    'Current Reading',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),

                  const SizedBox(height: 8),

                  // BPM value — tap to manually enter
                  TextField(
                    controller: bpmController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: '--',
                      hintStyle: TextStyle(fontSize: 48, color: Colors.grey),
                      border: InputBorder.none,
                      suffixText: 'BPM',
                      suffixStyle: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _currentBpm = int.tryParse(value) ?? 0;
                      });
                    },
                  ),

                  const SizedBox(height: 8),

                  // Status row with color indicator
                  if (bpm > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Heart Rate',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Status color bar (low -> normal -> elevated -> high)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.red,
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Labels under bar
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('60', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('100', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ---- Measure + Save buttons ----
            // Measure button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isMeasuring ? null : _startMeasuring,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.15),
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isMeasuring ? 'Measuring...' : 'Start Measuring',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Save Reading button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveReading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Save Reading',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}