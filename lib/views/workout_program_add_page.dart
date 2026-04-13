import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
  final ImagePicker _picker = ImagePicker();

  // Form fields
  final TextEditingController _programNameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  String _selectedGoal = 'Strength';
  String _selectedDifficulty = 'Beginner';

  final List<String> _goals = ['Strength', 'Cardio', 'Flexibility', 'Weight Loss', 'Muscle Gain'];
  final List<String> _difficulties = ['Beginner', 'Intermediate', 'Advanced'];

  // Exercise library mapping for auto-select
  final Map<String, String> _exerciseToBodyPart = {
    'Squat': 'Leg',
    'Lunges': 'Leg',
    'Leg Press': 'Leg',
    'Push-ups': 'Chest',
    'Bench Press': 'Chest',
    'Bicep Curls': 'Arm',
    'Tricep Dips': 'Arm',
  };

  // Difficulty settings: Difficulty -> {sets, repeat}
  final Map<String, Map<String, int>> _difficultySettings = {
    'Beginner': {'sets': 2, 'repeat': 10},
    'Intermediate': {'sets': 3, 'repeat': 12},
    'Advanced': {'sets': 4, 'repeat': 15},
  };

  // Exercise fields
  List<ExerciseForm> _exercises = [];

  @override
  void initState() {
    super.initState();
    _addExercise();
  }

  void _addExercise() {
    final settings = _difficultySettings[_selectedDifficulty]!;
    setState(() {
      _exercises.add(ExerciseForm(
        exerciseNameController: TextEditingController(text: 'Squat'),
        selectedBodyPart: 'Leg',
        imageUrls: [],
        sets: settings['sets']!,
        repeat: settings['repeat']!,
        instructionsController: TextEditingController(),
      ));
    });
  }

  void _updateAllExerciseDifficulty() {
    final settings = _difficultySettings[_selectedDifficulty]!;
    setState(() {
      for (var exercise in _exercises) {
        exercise.sets = settings['sets']!;
        exercise.repeat = settings['repeat']!;
      }
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises[index].dispose();
      _exercises.removeAt(index);
    });
  }

  Future<void> _pickImages(int index) async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        setState(() {
          for (var file in pickedFiles) {
            if (_exercises[index].imageUrls.length < 5) {
              _exercises[index].imageUrls.add(file.path);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _removeImage(int exerciseIndex, int imageIndex) {
    setState(() {
      _exercises[exerciseIndex].imageUrls.removeAt(imageIndex);
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

  Future<void> _saveWorkout() async {
    if (_formKey.currentState!.validate()) {
      final workoutId = _uuid.v4();
      final workout = Workout(
        id: workoutId,
        name: _programNameController.text,
        description: '${_exercises.length} exercises - ${_durationController.text} min',
        exerciseCount: _exercises.length,
        durationMinutes: int.tryParse(_durationController.text) ?? 30,
        difficulty: _selectedDifficulty,
        color: '0xFFDAD9FF', // Default purple color
      );

      final exerciseModels = _exercises.map((f) => Exercise(
        id: _uuid.v4(),
        workoutId: workoutId,
        name: f.exerciseNameController.text,
        sets: f.sets,
        reps: f.repeat,
        instructions: f.instructionsController.text,
        imageUrls: f.imageUrls,
      )).toList();

      await _controller.addWorkout(workout, exerciseModels);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout program added successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.black87, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Text('Add Workout Program', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),

            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFD4E4F7), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(color: const Color(0xFF9FA8DA), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.add, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Add Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              Text('Logged at ${_getCurrentTime()}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Add New Workout Program', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 20),
                          _buildLabel('Program name'),
                          _buildTextField(controller: _programNameController, hintText: 'Leg Workout'),
                          const SizedBox(height: 16),
                          _buildLabel('Goal'),
                          _buildDropdown(value: _selectedGoal, items: _goals, onChanged: (value) => setState(() => _selectedGoal = value!)),
                          const SizedBox(height: 16),
                          _buildLabel('Durations'),
                          _buildTextField(controller: _durationController, hintText: '30 mins', keyboardType: TextInputType.number),
                          const SizedBox(height: 16),
                          _buildLabel('Difficulty'),
                          _buildDropdown(
                            value: _selectedDifficulty,
                            items: _difficulties,
                            onChanged: (value) {
                              setState(() {
                                _selectedDifficulty = value!;
                                _updateAllExerciseDifficulty();
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Preview Image'),
                          _buildUploadField('Tap to select preview image', Icons.upload, () {}),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Exercise(s)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        TextButton.icon(
                          onPressed: _addExercise,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add More'),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF9FA8DA)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    ..._exercises.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildExerciseForm(entry.value, entry.key),
                    )),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveWorkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDAD9FF),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Add Record', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[600])));
  }

  Widget _buildTextField({required TextEditingController controller, required String hintText, TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hintText, border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey[500])),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildDropdown({required String value, required List<String> items, required ValueChanged<String?> onChanged, bool enabled = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: enabled ? Colors.grey[200] : Colors.grey[300], borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: enabled ? Colors.black87 : Colors.grey),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: enabled ? Colors.black87 : Colors.grey[600]),
          items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildUploadField(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(text, style: TextStyle(fontSize: 16, color: Colors.grey[600])), Icon(icon, color: Colors.grey[700])]),
      ),
    );
  }

  Widget _buildExerciseForm(ExerciseForm exercise, int index) {
    final bodyParts = ['Leg', 'Chest', 'Arm', 'Back', 'Shoulder', 'Core'];
    final exerciseNames = _exerciseToBodyPart.keys.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_exercises.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Exercise ${index + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeExercise(index)),
              ],
            ),

          _buildLabel('Exercise'),
          _buildDropdown(
            value: exerciseNames.contains(exercise.exerciseNameController.text) ? exercise.exerciseNameController.text : exerciseNames[0],
            items: exerciseNames,
            onChanged: (value) {
              setState(() {
                exercise.exerciseNameController.text = value!;
                if (_exerciseToBodyPart.containsKey(value)) {
                  exercise.selectedBodyPart = _exerciseToBodyPart[value]!;
                }
              });
            },
          ),
          const SizedBox(height: 16),

          _buildLabel('Focus Body Part'),
          _buildDropdown(
            value: exercise.selectedBodyPart,
            items: bodyParts,
            enabled: false, // Match edit page logic
            onChanged: (value) => setState(() => exercise.selectedBodyPart = value!),
          ),
          const SizedBox(height: 16),

          _buildLabel('Exercise Images (Multiple)'),
          _buildUploadField(
            exercise.imageUrls.isEmpty ? 'Select images from gallery' : '${exercise.imageUrls.length} images selected',
            Icons.add_photo_alternate,
            () => _pickImages(index),
          ),
          
          if (exercise.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: exercise.imageUrls.length,
                itemBuilder: (context, imgIndex) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(image: FileImage(File(exercise.imageUrls[imgIndex])), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        right: 4, top: 0,
                        child: GestureDetector(
                          onTap: () => _removeImage(index, imgIndex),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Sets'),
                    _buildCounterField(value: exercise.sets, onDecrement: () { if (exercise.sets > 1) setState(() => exercise.sets--); }, onIncrement: () => setState(() => exercise.sets++)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Repeat'),
                    _buildCounterField(value: exercise.repeat, onDecrement: () { if (exercise.repeat > 1) setState(() => exercise.repeat--); }, onIncrement: () => setState(() => exercise.repeat++)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildLabel('Instructions'),
          _buildTextField(controller: exercise.instructionsController, hintText: 'Enter exercise instructions...', maxLines: 4),
        ],
      ),
    );
  }

  Widget _buildCounterField({required int value, required VoidCallback onDecrement, required VoidCallback onIncrement}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(onTap: onDecrement, child: const Icon(Icons.remove, size: 20, color: Colors.black87)),
          const SizedBox(width: 16),
          Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(width: 16),
          GestureDetector(onTap: onIncrement, child: const Icon(Icons.add, size: 20, color: Colors.black87)),
        ],
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} - ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][now.month - 1]} ${now.day}';
  }
}

class ExerciseForm {
  final TextEditingController exerciseNameController;
  String selectedBodyPart;
  List<String> imageUrls;
  int sets;
  int repeat;
  final TextEditingController instructionsController;

  ExerciseForm({
    required this.exerciseNameController,
    required this.selectedBodyPart,
    required this.imageUrls,
    required this.sets,
    required this.repeat,
    required this.instructionsController,
  });

  void dispose() {
    exerciseNameController.dispose();
    instructionsController.dispose();
  }
}
