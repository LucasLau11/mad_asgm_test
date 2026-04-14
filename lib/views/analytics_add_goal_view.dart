import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/analytics_app_state.dart';
import '../models/analytics_goal_model.dart';

class AddGoalView extends StatefulWidget {
  final GoalModel? existingGoal;
  const AddGoalView({super.key, this.existingGoal});

  @override
  State<AddGoalView> createState() => _AddGoalViewState();
}

class _AddGoalViewState extends State<AddGoalView> {
  String? _selectedGoal;
  String? _selectedTarget;
  DateTime? _selectedDeadline;
  final TextEditingController _reasonController = TextEditingController();

  AnalyticsAppState get _appState => context.read<AnalyticsAppState>();

  List<String> get _goalTypes => [
    'Cal Burned',
    'Steps Walked',
    _appState.isMetric ? 'Km Ran' : 'Miles Ran',
    'Workouts Completed',
    _appState.isMetric ? 'Weight Lost (kg)' : 'Weight Lost (lbs)',
  ];

  Map<String, List<String>> get _targetsByGoal => {
    'Cal Burned':         ['200', '500', '750', '1000', '1500', '2000', '3000', '5000'],
    'Steps Walked':       ['1000', '3000', '5000', '8000', '10000', '15000'],
    'Km Ran':             ['1', '3', '5', '10', '15', '21'],
    'Miles Ran':          ['1', '2', '3', '6', '10', '13'],
    'Workouts Completed': ['3', '5', '10', '15', '20', '30'],
    'Weight Lost (kg)':   ['1', '2', '3', '5', '7', '10'],
    'Weight Lost (lbs)':  ['2', '5', '7', '10', '15', '22'],
  };

  Map<String, String> get _unitByGoal => {
    'Cal Burned':         'kcal',
    'Steps Walked':       'steps',
    'Km Ran':             'km',
    'Miles Ran':          'miles',
    'Workouts Completed': 'sessions',
    'Weight Lost (kg)':   'kg',
    'Weight Lost (lbs)':  'lbs',
  };

  bool get _isEditing => widget.existingGoal != null;
  List<String> get _currentTargets =>
      _selectedGoal != null ? (_targetsByGoal[_selectedGoal!] ?? []) : [];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final g = widget.existingGoal!;
      String resolvedGoalType = g.goalType;

      const metricToImperial = {
        'Km Ran': 'Miles Ran',
        'Weight Lost (kg)': 'Weight Lost (lbs)',
      };
      const imperialToMetric = {
        'Miles Ran': 'Km Ran',
        'Weight Lost (lbs)': 'Weight Lost (kg)',
      };

      final appState = context.read<AnalyticsAppState>();
      if (appState.isMetric && imperialToMetric.containsKey(g.goalType)) {
        resolvedGoalType = imperialToMetric[g.goalType]!;
      } else if (!appState.isMetric && metricToImperial.containsKey(g.goalType)) {
        resolvedGoalType = metricToImperial[g.goalType]!;
      }

      _selectedGoal = resolvedGoalType;
      _selectedDeadline = DateTime.tryParse(g.deadline);
      _reasonController.text = g.reason;

      final validTargets = _targetsByGoal[resolvedGoalType] ?? [];
      _selectedTarget = validTargets.contains(g.target) ? g.target : null;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _onGoalChanged(String? val) {
    setState(() {
      _selectedGoal = val;
      final newTargets = _targetsByGoal[val] ?? [];
      if (!newTargets.contains(_selectedTarget)) _selectedTarget = null;
    });
  }

  Future<void> _pickDeadline() async {
    final appState = context.read<AnalyticsAppState>();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF5B4FCF),
              onPrimary: Colors.white,
              surface: appState.darkMode ? const Color(0xFF1E1E1E) : Colors.white,
              onSurface: appState.darkMode ? Colors.white : Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDeadline = picked);
  }

  bool get _canSave =>
      _selectedGoal != null && _selectedTarget != null && _selectedDeadline != null;

  void _save() {
    final appState = context.read<AnalyticsAppState>();
    final goal = GoalModel(
      id: _isEditing
          ? widget.existingGoal!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      goalType: _selectedGoal!,
      target:   _selectedTarget!,
      deadline: DateFormat('dd MMM yyyy').format(_selectedDeadline!),
      reason:   _reasonController.text.trim(),
      progress: _isEditing ? widget.existingGoal!.progress : 0,
    );

    if (_isEditing) {
      appState.updateGoal(goal);
    } else {
      appState.addGoal(goal);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalyticsAppState>(
      builder: (context, appState, _) {
        final isDark = appState.darkMode;
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subtitleColor = isDark ? Colors.white54 : Colors.black45;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black,
            elevation: 0,
            leading: const BackButton(),
            title: Text(_isEditing ? 'Edit Goal' : 'Add Goal(s)'),
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  _dropdownField(
                    hint: 'Select A Goal To Track',
                    value: _selectedGoal,
                    items: _goalTypes,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    onChanged: _onGoalChanged,
                  ),
                  const SizedBox(height: 12),
                  _dropdownField(
                    hint: _selectedGoal == null
                        ? 'Select a goal first'
                        : 'What is your target? (${_unitByGoal[_selectedGoal]})',
                    value: _selectedTarget,
                    items: _currentTargets,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    onChanged: _selectedGoal == null
                        ? null
                        : (v) => setState(() => _selectedTarget = v),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickDeadline,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDeadline != null
                                ? DateFormat('dd MMM yyyy').format(_selectedDeadline!)
                                : "What's the deadline?",
                            style: TextStyle(
                              fontSize: 15,
                              color: _selectedDeadline != null ? textColor : subtitleColor,
                            ),
                          ),
                          Icon(Icons.calendar_today_outlined, size: 18, color: subtitleColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10)),
                    child: TextField(
                      controller: _reasonController,
                      style: TextStyle(fontSize: 15, color: textColor),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Why this goal? (optional)',
                        hintStyle: TextStyle(fontSize: 15, color: subtitleColor),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSave ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B4FCF),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF5B4FCF).withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _isEditing ? 'Update Goal' : 'Add Goal',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dropdownField({
    required String hint,
    required String? value,
    required List<String> items,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
    required ValueChanged<String?>? onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 15, color: subtitleColor)),
          isExpanded: true,
          dropdownColor: cardColor,
          style: TextStyle(fontSize: 15, color: textColor),
          icon: Icon(Icons.keyboard_arrow_down, color: subtitleColor),
          onChanged: onChanged,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        ),
      ),
    );
  }
}
