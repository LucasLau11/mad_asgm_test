import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/exercise_controller.dart';
import '../../models/exercise_model/exercise_model.dart';
import '../../models/analytic_model/analytics_app_state.dart';

class AddExerciseView extends StatefulWidget {
  final Exercise? exercise;

  const AddExerciseView({Key? key, this.exercise}) : super(key: key);

  @override
  State<AddExerciseView> createState() => _AddExerciseViewState();
}

class _AddExerciseViewState extends State<AddExerciseView> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  late TextEditingController _titleController;
  late TextEditingController _distanceController;
  late TextEditingController _caloriesController;
  late TextEditingController _stepsController;
  late TextEditingController _notesController;

  // Goal controllers (FIXED - Initialize these!)
  late TextEditingController _stepGoalController;
  late TextEditingController _distanceGoalController;
  late TextEditingController _timeGoalController;

  // Form values
  ExerciseType _selectedType = ExerciseType.walking;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _durationMinutes = 30;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();

    _isEditing = widget.exercise != null;

    if (_isEditing) {
      final exercise = widget.exercise!;
      _titleController = TextEditingController(text: exercise.title);
      _selectedType = exercise.type;
      _selectedDate = exercise.startTime;
      _selectedTime = TimeOfDay.fromDateTime(exercise.startTime);
      _durationMinutes = exercise.durationMinutes;
      _distanceController = TextEditingController(
        text: exercise.distanceKm?.toString() ?? '',
      );
      _caloriesController = TextEditingController(
        text: exercise.energyExpended?.toString() ?? '',
      );
      _stepsController = TextEditingController(
        text: exercise.steps?.toString() ?? '',
      );
      _notesController = TextEditingController(text: exercise.notes ?? '');

      // Initialize goal controllers (FIXED!)
      _stepGoalController = TextEditingController(
        text: exercise.stepGoal?.toString() ?? '',
      );
      _distanceGoalController = TextEditingController(
        text: exercise.distanceGoal?.toString() ?? '',
      );
      _timeGoalController = TextEditingController(
        text: exercise.timeGoal?.toString() ?? '',
      );
    } else {
      _titleController = TextEditingController();
      _distanceController = TextEditingController();
      _caloriesController = TextEditingController();
      _stepsController = TextEditingController();
      _notesController = TextEditingController();

      // Initialize goal controllers (FIXED!)
      _stepGoalController = TextEditingController();
      _distanceGoalController = TextEditingController();
      _timeGoalController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _distanceController.dispose();
    _caloriesController.dispose();
    _stepsController.dispose();
    _notesController.dispose();

    // Dispose goal controllers (FIXED!)
    _stepGoalController.dispose();
    _distanceGoalController.dispose();
    _timeGoalController.dispose();

    super.dispose();
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = Provider.of<ExerciseController>(context, listen: false);

    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final distance = _distanceController.text.isEmpty
        ? null
        : double.tryParse(_distanceController.text);

    final calories = _caloriesController.text.isEmpty
        ? null
        : int.tryParse(_caloriesController.text);

    final steps = _stepsController.text.isEmpty
        ? null
        : int.tryParse(_stepsController.text);

    // Parse goals (FIXED!)
    final stepGoal = _stepGoalController.text.isEmpty
        ? null
        : int.tryParse(_stepGoalController.text);

    final distanceGoal = _distanceGoalController.text.isEmpty
        ? null
        : double.tryParse(_distanceGoalController.text);

    final timeGoal = _timeGoalController.text.isEmpty
        ? null
        : int.tryParse(_timeGoalController.text);

    final exercise = Exercise(
      id: _isEditing ? widget.exercise!.id : null,
      title: _titleController.text.isEmpty ? '' : _titleController.text,
      type: _selectedType,
      startTime: startDateTime,
      durationMinutes: _durationMinutes,
      distanceKm: distance,
      energyExpended: calories,
      steps: steps,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      routePoints: _isEditing ? widget.exercise!.routePoints : null,
      stepGoal: stepGoal,
      distanceGoal: distanceGoal,
      timeGoal: timeGoal,
    );

    if (_isEditing) {
      await controller.updateExercise(exercise);
    } else {
      await controller.createExercise(exercise);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AnalyticsAppState>();
    final isDark = appState.darkMode;
    final bg = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[500] : Colors.grey[400];
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit exercise' : 'Add exercise',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveExercise,
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── Title field ──
            _buildTitleField(textColor, hintColor),
            Divider(height: 1, color: isDark ? Colors.grey[800] : null),

            // Exercise Type
            _buildFieldRow(
              label: 'Exercise',
              value: _selectedType.displayName,
              onTap: _showExerciseTypePicker,
              textColor: textColor,
            ),
            Divider(height: 1, color: isDark ? Colors.grey[800] : null),

            // Start Date & Time
            _buildFieldRow(
              label: 'Start',
              value: '${_formatDate(_selectedDate)}   ${_selectedTime.format(context)}',
              onTap: _showDateTimePicker,
              textColor: textColor,
            ),
            Divider(height: 1, color: isDark ? Colors.grey[800] : null),

            // Duration
            _buildFieldRow(
              label: 'Duration',
              value: '$_durationMinutes min',
              onTap: _showDurationPicker,
              textColor: textColor,
            ),
            Divider(height: 1, color: isDark ? Colors.grey[800] : null),

            // Distance
            _buildFieldRow(
              label: 'Distance',
              value: _distanceController.text.isEmpty
                  ? 'add distance'
                  : '${_distanceController.text} km',
              onTap: () {
                _showNumberInputDialog(
                  title: 'Distance',
                  controller: _distanceController,
                  suffix: 'km',
                  isDecimal: true,
                  maxValue: 100.0,   // max 100 km
                  minValue: 0.1,     // min 0.1 km
                );
              },
              textColor: textColor,
            ),
            Divider(height: 1, color: isDark ? Colors.grey[800] : null),

            // Energy Expended (Calories)
            _buildFieldRow(
              label: 'Energy expended',
              value: _caloriesController.text.isEmpty
                  ? 'add calories'
                  : '${_caloriesController.text} cal',
              onTap: () {
                _showNumberInputDialog(
                  title: 'Calories Burned',
                  controller: _caloriesController,
                  suffix: 'cal',
                  maxValue: 1000,    // max 1000 cal
                  minValue: 1,       // min 1 cal
                );
              },
              textColor: textColor,
            ),
            Divider(height: 1, color: isDark ? Colors.grey[800] : null),

            // Steps
            _buildFieldRow(
              label: 'Steps',
              value: _stepsController.text.isEmpty
                  ? 'add steps'
                  : '${_stepsController.text} steps',
              onTap: () {
                _showNumberInputDialog(
                  title: 'Steps',
                  controller: _stepsController,
                  suffix: 'steps',
                  maxValue: 10000,  // max 10,000 steps
                  minValue: 1,       // min 1 step
                );
              },
              textColor: textColor,
            ),
            Divider(height: 1, color: isDark ? Colors.grey[800] : null),

            const SizedBox(height: 20),

            // Notes
            Text(
              'Add note',
              style: TextStyle(
                fontSize: 15,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 5,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Enter your notes here...',
                hintStyle: TextStyle(color: hintColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField(Color textColor, Color? hintColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              'Title',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                hintText: 'e.g. Morning Walk',
                hintStyle: TextStyle(color: hintColor, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _titleController,
                  builder: (_, value, __) => value.text.isNotEmpty
                      ? GestureDetector(
                    onTap: () => _titleController.clear(),
                    child: const Icon(Icons.clear,
                        size: 18, color: Colors.grey),
                  )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExerciseTypePicker() {
    final isDark = context.read<AnalyticsAppState>().darkMode;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ...ExerciseType.values.map((type) {
                return ListTile(
                  leading: Icon(type.icon, color: type.color),
                  title: Text(type.displayName, style: TextStyle(color: textColor)),
                  trailing: _selectedType == type
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedType = type;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showDateTimePicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
        });
      }
    }
  }

  void _showDurationPicker() {
    final isDark = context.read<AnalyticsAppState>().darkMode;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 50,
                  perspective: 0.005,
                  diameterRatio: 1.2,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _durationMinutes = (index + 1) * 5;
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 60,
                    builder: (context, index) {
                      final minutes = (index + 1) * 5;
                      return Center(
                        child: Text(
                          '$minutes min',
                          style: TextStyle(
                            fontSize: minutes == _durationMinutes ? 20 : 16,
                            fontWeight: minutes == _durationMinutes
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: textColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNumberInputDialog({
    required String title,
    required TextEditingController controller,
    required String suffix,
    bool isDecimal = false,
    double? maxValue,
    double? minValue,
  }) {
    final tempController = TextEditingController(text: controller.text);
    String? errorText;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: tempController,
                keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
                decoration: InputDecoration(
                  suffix: Text(suffix),
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                autofocus: true,
                onChanged: (value) {
                  setDialogState(() {
                    errorText = null; // clear error on change
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final input = tempController.text.trim();

                    // Empty is allowed (clears the field)
                    if (input.isEmpty) {
                      setState(() => controller.text = '');
                      Navigator.pop(context);
                      return;
                    }

                    // Must be a valid number
                    final parsed = isDecimal
                        ? double.tryParse(input)
                        : int.tryParse(input)?.toDouble();

                    if (parsed == null) {
                      setDialogState(() {
                        errorText = 'Please enter a valid number';
                      });
                      return;
                    }

                    // Must not be negative or zero
                    if (parsed <= 0) {
                      setDialogState(() {
                        errorText = 'Value must be greater than 0';
                      });
                      return;
                    }

                    // Max value check
                    if (maxValue != null && parsed > maxValue) {
                      setDialogState(() {
                        errorText = 'Maximum allowed is $maxValue $suffix';
                      });
                      return;
                    }

                    // Min value check
                    if (minValue != null && parsed < minValue) {
                      setDialogState(() {
                        errorText = 'Minimum allowed is $minValue $suffix';
                      });
                      return;
                    }

                    setState(() => controller.text = input);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) {
      return 'Today';
    } else if (compareDate == yesterday) {
      return 'Yesterday';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${_getDayName(date.weekday)} ${date.day} ${months[date.month - 1]}';
    }
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}