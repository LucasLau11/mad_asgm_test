import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../controllers/workout_controller.dart';
import '../../services/database/heart_rate_database_service.dart';
import '../../models/workout_model/workout_model.dart';
import '../../models/workout_model/workout_exercise_model.dart';

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

  final TextEditingController _programNameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  String _selectedGoal = 'Strength';
  String _selectedDifficulty = 'Beginner';
  String? _previewImagePath;
  final List<String> _goals = ['Strength', 'Cardio', 'Flexibility', 'Weight Loss', 'Muscle Gain'];
  final List<String> _difficulties = ['Beginner', 'Intermediate', 'Advanced'];

  final Map<String, String> _exerciseToBodyPart = {
    'Squat': 'Leg',
    'Jumping Jack': 'Full Body',
    'Push-ups': 'Chest',

  };

  final Map<String, Map<String, int>> _difficultySettings = {
    'Beginner': {'sets': 2, 'repeat': 10},
    'Intermediate': {'sets': 3, 'repeat': 12},
    'Advanced': {'sets': 4, 'repeat': 15},
  };
  final Map<String, String> _predefinedInstructions = {
    'Squat': '1. Stand with feet shoulder-width apart.\n2. Keep your back straight and lower your hips as if sitting in a chair.\n3. Go down until thighs are parallel to the floor.\n4. Push through heels to return to start.',
    'Jumping Jack': '1. Stand upright with your feet together and arms at your sides.\n2. Jump while spreading your legs shoulder-width apart and raising your arms overhead.\n3. Quickly reverse the movement by jumping back to the starting position.\n4. Repeat in a steady rhythm while keeping your core engaged.',
    'Push-ups': '1. Start in a plank position.\n2. Lower your body until your chest nearly touches the floor.\n3. Keep your core tight and back flat.\n4. Push back up to the starting position.',
  };
  List<ExerciseForm> _exercises = [];

  @override
  void initState() {
    super.initState();
    _addExercise();
  }
  void _showTimerPicker() {
    // Get current value from the controller or default to 30
    int currentMinutes = int.tryParse(_durationController.text) ?? 30;

    // Controller to set the initial position of the wheel
    FixedExtentScrollController wheelController = FixedExtentScrollController(
        initialItem: (currentMinutes > 0) ? currentMinutes - 1 : 0
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                "Select Duration (Minutes)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  controller: wheelController,
                  itemExtent: 50,
                  perspective: 0.005,
                  diameterRatio: 1.2,
                  physics: const FixedExtentScrollPhysics(),
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 120, // Allows up to 120 minutes
                    builder: (context, index) => Center(
                      child: Text(
                        '${index + 1} mins',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDAD9FF),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                    setState(() {
                      _durationController.text = (wheelController.selectedItem + 1).toString();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Confirm", style: TextStyle(color: Colors.black87)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _syncDifficultyFromExercises() {
    if (_exercises.isEmpty) return;

    // Calculate average sets
    double avgSets = _exercises.fold(0, (sum, ex) => sum + ex.sets) / _exercises.length;

    String newDifficulty;
    if (avgSets <= 2.2) {
      newDifficulty = 'Beginner';
    } else if (avgSets <= 3.2) {
      newDifficulty = 'Intermediate';
    } else {
      newDifficulty = 'Advanced';
    }

    if (_selectedDifficulty != newDifficulty) {
      setState(() {
        _selectedDifficulty = newDifficulty;
      });
    }
  }
  void _syncMetadata() {
    if (_exercises.isEmpty) return;

    int totalSets = _exercises.fold(0, (sum, ex) => sum + ex.sets);
    int estimatedDuration = (totalSets * 3) + 5;
    _durationController.text = estimatedDuration.toString();

    double avgSets = totalSets / _exercises.length;
    String newDifficulty;
    if (avgSets <= 2.2) {
      newDifficulty = 'Beginner';
    } else if (avgSets <= 3.2) {
      newDifficulty = 'Intermediate';
    } else {
      newDifficulty = 'Advanced';
    }

    if (_selectedDifficulty != newDifficulty) {
      setState(() {
        _selectedDifficulty = newDifficulty;
      });
    }
  }
  Future<void> _pickPreviewImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final fileSize = await File(pickedFile.path).length();
        if (fileSize > 2 * 1024 * 1024) { // 2MB Limit
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Preview image must be less than 2MB'), backgroundColor: Colors.orange),
            );
          }
          return;
        }
        setState(() {
          _previewImagePath = pickedFile.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking preview image: $e');
    }
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
    _syncMetadata();
  }

  void _updateAllExerciseDifficulty(String difficulty) {
    final settings = _difficultySettings[difficulty]!;
    setState(() {
      _selectedDifficulty = difficulty;
      for (var exercise in _exercises) {
        exercise.sets = settings['sets']!;
        exercise.repeat = settings['repeat']!;
      }
    });
    _syncMetadata();
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises[index].dispose();
      _exercises.removeAt(index);
    });
    _syncMetadata();
  }

  Future<void> _pickImages(int index) async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        for (var file in pickedFiles) {
          final fileSize = await File(file.path).length();
          if (fileSize > 2 * 1024 * 1024) { // 2MB Limit
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image size must be less than 2MB'), backgroundColor: Colors.orange),
              );
            }
            continue;
          }
          setState(() {
            if (_exercises[index].imageUrls.length < 5) {
              _exercises[index].imageUrls.add(file.path);
            }
          });
        }
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
      /*// Custom validation for exercises
      for (var ex in _exercises) {
        if (ex.imageUrls.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please add at least one image per exercise'), backgroundColor: Colors.red),
          );
          return;
        }
      }*/

      try {
        final workoutId = _uuid.v4();
        final currentUserId = DatabaseService.currentUserId;

        final workout = Workout(
          id: workoutId,
          userId: currentUserId,
          name: _programNameController.text,
          goal: _selectedGoal,
          description: '${_exercises.length} exercises - ${_durationController.text} min',
          exerciseCount: _exercises.length,
          durationMinutes: int.tryParse(_durationController.text) ?? 30,
          difficulty: _selectedDifficulty,
          color: '0xFFDAD9FF',
          imageUrl: _previewImagePath ?? '',
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
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
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
                  const Text('Add Workout', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
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
                            width: 50, height: 50,
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
                          _buildLabel('Durations (Estimated in mins)'),
                          GestureDetector(
                            onTap: _showTimerPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12)
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_durationController.text} mins',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                                  ),
                                  const Icon(Icons.timer_outlined, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),                          const SizedBox(height: 16),
                          _buildLabel('Difficulty'),
                          _buildDropdown(
                            value: _selectedDifficulty,
                            items: _difficulties,
                            onChanged: (value) => _updateAllExerciseDifficulty(value!),
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Preview Image'),
                          const SizedBox(height: 8),
                          _previewImagePath != null
                              ? Stack(
                            children: [
                              Container(
                                height: 160,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: FileImage(File(_previewImagePath!)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() => _previewImagePath = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          )
                              : _buildUploadField(
                            'Tap to select preview image',
                            Icons.upload,
                            _pickPreviewImage, // Call the new function
                          ),
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
    final bodyParts = ['Leg', 'Chest', 'Arm', 'Back', 'Shoulder', 'Full Body'];
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
            enabled: false,
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
                    _buildCounterField(
                      value: exercise.sets,
                      onDecrement: () { if (exercise.sets > 1) { setState(() => exercise.sets--); _syncMetadata(); } },
                      onIncrement: () { setState(() => exercise.sets++); _syncMetadata(); },
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
                      onDecrement: () { if (exercise.repeat > 1) { setState(() => exercise.repeat--); _syncMetadata(); } },
                      onIncrement: () { setState(() => exercise.repeat++); _syncMetadata(); },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabel('Instructions'),
              // Only show the button if the current exercise has a preset available
              if (_predefinedInstructions.containsKey(exercise.exerciseNameController.text))
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      exercise.instructionsController.text =
                      _predefinedInstructions[exercise.exerciseNameController.text]!;
                    });
                  },
                  icon: const Icon(Icons.description, size: 14),
                  label: const Text('Use Preset', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF9FA8DA),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          _buildTextField(
              controller: exercise.instructionsController,
              hintText: 'Enter exercise instructions...',
              maxLines: 4
          ),
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
