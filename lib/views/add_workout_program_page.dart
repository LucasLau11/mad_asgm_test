import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../controllers/workout_controller.dart';
import '../models/workout_model.dart';
import '../models/workout_exercise_model.dart';

class AddWorkoutProgramPage extends StatefulWidget {
  const AddWorkoutProgramPage({Key? key}) : super(key: key);

  @override
  State<AddWorkoutProgramPage> createState() => _AddWorkoutProgramPageState();
}

class _AddWorkoutProgramPageState extends State<AddWorkoutProgramPage> {
  final _formKey = GlobalKey<FormState>();
  final WorkoutController _controller = WorkoutController();
  final Uuid _uuid = const Uuid();

  // Form fields
  final TextEditingController _programNameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  String _selectedGoal = 'Strength';
  String _selectedDifficulty = 'Beginner';

  final List<String> _goals = ['Strength', 'Cardio', 'Flexibility', 'Weight Loss', 'Muscle Gain'];
  final List<String> _difficulties = ['Beginner', 'Intermediate', 'Advanced'];

  // Exercise fields
  List<ExerciseForm> _exercises = [];

  @override
  void initState() {
    super.initState();
    // Add one default exercise form
    _addExercise();
  }

  void _addExercise() {
    setState(() {
      _exercises.add(ExerciseForm(
        exerciseNameController: TextEditingController(text: 'Squat'),
        selectedBodyPart: 'Leg',
        videoUrlController: TextEditingController(),
        sets: 3,
        repeat: 12,
        instructionsController: TextEditingController(),
      ));
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises[index].dispose();
      _exercises.removeAt(index);
    });
  }

  @override
  void dispose() {
    _programNameController.dispose();
    _durationController.dispose();
    for (var exercise in _exercises) {
      exercise.dispose();
    }
    super.dispose();
  }

  void _saveWorkout() {
    if (_formKey.currentState!.validate()) {
      // TODO: Save to database
      // For now, just show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout program added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.black87,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Add Workout Program',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Record Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4E4F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9FA8DA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add Record',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Logged at ${_getCurrentTime()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Add New Workout Program Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add New Workout Program',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Program Name
                          _buildLabel('Program name'),
                          _buildTextField(
                            controller: _programNameController,
                            hintText: 'Leg Workout',
                          ),
                          const SizedBox(height: 16),

                          // Goal
                          _buildLabel('Goal'),
                          _buildDropdown(
                            value: _selectedGoal,
                            items: _goals,
                            onChanged: (value) {
                              setState(() {
                                _selectedGoal = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Durations
                          _buildLabel('Durations'),
                          _buildTextField(
                            controller: _durationController,
                            hintText: '30 mins',
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),

                          // Difficulty
                          _buildLabel('Difficulty'),
                          _buildDropdown(
                            value: _selectedDifficulty,
                            items: _difficulties,
                            onChanged: (value) {
                              setState(() {
                                _selectedDifficulty = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Preview Image
                          _buildLabel('Preview Image'),
                          _buildUploadField('Maximum 2MB', Icons.upload),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Exercise(s) Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Exercise(s)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addExercise,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add More'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF9FA8DA),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Exercise Forms
                    ..._exercises.asMap().entries.map((entry) {
                      int index = entry.key;
                      ExerciseForm exercise = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildExerciseForm(exercise, index),
                      );
                    }),

                    const SizedBox(height: 24),

                    // Add Record Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveWorkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDAD9FF),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Add Record',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildUploadField(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          Icon(icon, color: Colors.grey[700]),
        ],
      ),
    );
  }

  Widget _buildExerciseForm(ExerciseForm exercise, int index) {
    final bodyParts = ['Leg', 'Chest', 'Arm', 'Back', 'Shoulder', 'Core'];
    final exerciseNames = ['Squat', 'Lunges', 'Leg Press', 'Push-ups', 'Bench Press', 'Bicep Curls', 'Tricep Dips'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise header with delete button
          if (_exercises.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Exercise ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeExercise(index),
                ),
              ],
            ),

          // Exercise Name
          _buildLabel('Exercise'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: exercise.exerciseNameController.text.isEmpty
                    ? exerciseNames[0]
                    : exercise.exerciseNameController.text,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                items: exerciseNames.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    exercise.exerciseNameController.text = value!;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Focus Body Part
          _buildLabel('Focus Body Part'),
          _buildDropdown(
            value: exercise.selectedBodyPart,
            items: bodyParts,
            onChanged: (value) {
              setState(() {
                exercise.selectedBodyPart = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // Video Guidance URL
          _buildLabel('Video Guidance URL'),
          _buildUploadField('Maximum 20MB', Icons.upload),
          const SizedBox(height: 16),

          // Sets and Repeat
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Sets'),
                    _buildCounterField(
                      value: exercise.sets,
                      onDecrement: () {
                        if (exercise.sets > 1) {
                          setState(() {
                            exercise.sets--;
                          });
                        }
                      },
                      onIncrement: () {
                        setState(() {
                          exercise.sets++;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Repeat'),
                    _buildCounterField(
                      value: exercise.repeat,
                      onDecrement: () {
                        if (exercise.repeat > 1) {
                          setState(() {
                            exercise.repeat--;
                          });
                        }
                      },
                      onIncrement: () {
                        setState(() {
                          exercise.repeat++;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Instructions
          _buildLabel('Instructions'),
          _buildTextField(
            controller: exercise.instructionsController,
            hintText: 'Enter exercise instructions...',
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildCounterField({
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.remove, size: 20, color: Colors.grey[700]),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.add, size: 20, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${hour}:${minute} AM - ${months[now.month - 1]} ${now.day}';
  }
}

class ExerciseForm {
  final TextEditingController exerciseNameController;
  String selectedBodyPart;
  final TextEditingController videoUrlController;
  int sets;
  int repeat;
  final TextEditingController instructionsController;

  ExerciseForm({
    required this.exerciseNameController,
    required this.selectedBodyPart,
    required this.videoUrlController,
    required this.sets,
    required this.repeat,
    required this.instructionsController,
  });

  void dispose() {
    exerciseNameController.dispose();
    videoUrlController.dispose();
    instructionsController.dispose();
  }
}