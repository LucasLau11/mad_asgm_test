import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/analytic_model/analytics_app_state.dart';
import '../../services/database/heart_rate_database_service.dart';
import '../../models/heart_rate_model/weight_model.dart';

class WeightEditPage extends StatefulWidget {
  final WeightModel record;

  const WeightEditPage({super.key, required this.record});

  @override
  State<WeightEditPage> createState() => _WeightEditPageState();
}

class _WeightEditPageState extends State<WeightEditPage> {
  final dbService = DatabaseService();

  late TextEditingController weightController;
  late TextEditingController noteController;

  double _toDisplay(double kg, bool isMetric) =>
      isMetric ? kg : kg * 2.20462;

  double _toKg(double displayVal, bool isMetric) =>
      isMetric ? displayVal : displayVal / 2.20462;

  String _unitLabel(bool isMetric) => isMetric ? 'kg' : 'lbs';

  @override
  void initState() {
    super.initState();
    noteController = TextEditingController(text: widget.record.note);
    weightController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set the initial value in the correct unit once context is available
    final isMetric = context.read<AnalyticsAppState>().isMetric;
    if (weightController.text.isEmpty) {
      weightController.text =
          _toDisplay(widget.record.weightKg, isMetric).toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    super.dispose();
    weightController.dispose();
    noteController.dispose();
  }

  void _saveChanges(bool isMetric) async {
    if (weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your weight.')));
      return;
    }

    final displayVal = double.tryParse(weightController.text) ?? 0;
    if (displayVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid weight.')));
      return;
    }

    // Convert back to kg
    final weightKg = _toKg(displayVal, isMetric);

    WeightModel updatedRecord = WeightModel(
      id: widget.record.id,
      weightKg: weightKg,
      note: noteController.text,
      createdOn: widget.record.createdOn,
    );

    await dbService.editWeightRecord(updatedRecord);

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record updated!')));
    Navigator.pop(context);
  }

  void _showDeleteBottomSheet() {
    final isMetric = context.read<AnalyticsAppState>().isMetric;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Delete Record?',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'You\'re about to delete the weight record at ${_formatTime(widget.record.createdOn)}. This action cannot be undone.',
                textAlign: TextAlign.center,
                style:
                const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              // Record preview
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surface : Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatDate(widget.record.createdOn)} - ${_formatTime(widget.record.createdOn)}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${_toDisplay(widget.record.weightKg, isMetric).toStringAsFixed(1)} ${_unitLabel(isMetric)}'
                              '${widget.record.note.isEmpty ? '' : ' - ${widget.record.note}'}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await dbService
                        .deleteWeightRecord(widget.record.id);
                    Navigator.pop(context); // close sheet
                    Navigator.pop(context); // go back
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF9A9A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Yes, Delete',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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

  String _formatDate(String dateTime) {
    if (dateTime.isEmpty) return '';
    try {
      DateTime dt = DateTime.parse(dateTime);
      DateTime now = DateTime.now();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      bool isToday = dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day;
      if (isToday) return 'Today, ${months[dt.month - 1]} ${dt.day}';
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (e) {
      return dateTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMetric = context.watch<AnalyticsAppState>().isMetric;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Weight',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Edit record banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surface : Colors.green,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.edit,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Editing Record',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      Text(
                        'Logged at ${_formatTime(widget.record.createdOn)}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // edit record card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
                  const Text('Update Details',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),

                  // Weight input — label & hint change with unit
                  Text('Weight (${_unitLabel(isMetric)})',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.grey
                    ),
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      suffixText: _unitLabel(isMetric),
                      suffixStyle:
                      const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[350],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFEEEEEE)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFEEEEEE)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                        const BorderSide(color: Colors.green),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Note input
                  const Text('Note (Optional)',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.grey
                    ),
                    controller: noteController,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[350],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFEEEEEE)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFEEEEEE)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                        const BorderSide(color: Colors.green),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Save Changes button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _saveChanges(isMetric),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9FA8DA),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Changes',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Delete Record button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _showDeleteBottomSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF9A9A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Delete Record',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}