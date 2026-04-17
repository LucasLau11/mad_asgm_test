import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../controllers/workout_controller.dart';
import '../models/workout_model.dart';
import '../models/workout_exercise_model.dart';

class EditWorkoutProgramPage extends StatefulWidget {
  final Workout workout;

  const EditWorkoutProgramPage({
    Key? key,
    required this.workout,
  }) : super(key: key);

  @override
  State<EditWorkoutProgramPage> createState() => _EditWorkoutProgramPageState();
}

class _EditWorkoutProgramPageState extends State<EditWorkoutProgramPage> {
  final _formKey = GlobalKey<FormState>();
  final WorkoutController _controller = WorkoutController();
  final ImagePicker _picker = ImagePicker();

  // Form fields
  late TextEditingController _programNameController;
  late TextEditingController _durationController;

  late String _selectedGoal;
  late String _selectedDifficulty;

  final List<String> _goals = ['Strength', 'Cardio', 'Flexibility', 'Weight Loss', 'Muscle Gain'];
  final List<String> _difficulties = ['Beginner', 'Intermediate', 'Advanced'];

  // Exercise library mapping for auto-select
  final Map<String, String> _exerciseToBodyPart = {
    'Squat': 'Leg',
    'Sit-up': 'Abdominal Muscle',
    'Push-ups': 'Chest',
  };

  // Difficulty settings
  final Map<String, Map<String, int>> _difficultySettings = {
    'Beginner': {'sets': 2, 'repeat': 10},
    'Intermediate': {'sets': 3, 'repeat': 12},
    'Advanced': {'sets': 4, 'repeat': 15},
  };
  final Map<String, String> _predefinedInstructions = {
    'Squat': '1. Stand with feet shoulder-width apart.\n2. Keep your back straight and lower your hips as if sitting in a chair.\n3. Go down until thighs are parallel to the floor.\n4. Push through heels to return to start.',
    'Sit-up': '1. Lie on your back with your knees bent and feet flat on the floor.\n2. Place your hands behind your head or cross them over your chest.\n3. Engage your core and lift your upper body until your chest is near your thighs.\n4. Slowly lower your back down to the starting position.',
    'Push-ups': '1. Start in a plank position.\n2. Lower your body until your chest nearly touches the floor.\n3. Keep your core tight and back flat.\n4. Push back up to the starting position.',
  };
  // Exercise fields
  List<EditExerciseForm> _exercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _programNameController = TextEditingController(text: widget.workout.name);
    _durationController = TextEditingController(text: widget.workout.durationMinutes.toString());
    _selectedGoal = 'Strength';
    _selectedDifficulty = widget.workout.difficulty;

    _loadExercises();
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

  void _showAndroidTimerPicker() {
    int currentVal = int.tryParse(_durationController.text) ?? 30;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text("Select Duration (Minutes)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 50,
                  perspective: 0.005,
                  diameterRatio: 1.2,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _durationController.text = (index + 1).toString();
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 120,
                    builder: (context, index) => Center(
                      child: Text('${index + 1} mins', style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Done"),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
    final exercises = await _controller.getExercisesForWorkout(widget.workout.id);
    setState(() {
      _exercises = exercises.map((exercise) {
        return EditExerciseForm(
          exerciseId: exercise.id,
          exerciseNameController: TextEditingController(text: exercise.name),
          selectedBodyPart: _exerciseToBodyPart[exercise.name] ?? 'Leg',
          imageUrls: List<String>.from(exercise.imageUrls),
          sets: exercise.sets,
          repeat: exercise.reps,
          instructionsController: TextEditingController(text: exercise.instructions),
        );
      }).toList();
      _isLoading = false;
    });

    if (_exercises.isEmpty) {
      _addExercise();
    }
  }

  void _addExercise() {
    final settings = _difficultySettings[_selectedDifficulty]!;
    setState(() {
      _exercises.add(EditExerciseForm(
        exerciseId: null,
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

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      try {
        final updatedWorkout = Workout(
          id: widget.workout.id,
          userId: widget.workout.userId,
          name: _programNameController.text,
          description: '${_exercises.length} exercises - ${_durationController.text} min',
          exerciseCount: _exercises.length,
          durationMinutes: int.tryParse(_durationController.text) ?? 30,
          difficulty: _selectedDifficulty,
          color: widget.workout.color,
        );

        final updatedExercises = _exercises.map((f) => Exercise(
          id: f.exerciseId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          workoutId: widget.workout.id,
          name: f.exerciseNameController.text,
          sets: f.sets,
          reps: f.repeat,
          instructions: f.instructionsController.text,
          imageUrls: f.imageUrls,
        )).toList();

        await _controller.updateWorkout(updatedWorkout, updatedExercises);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout updated successfully!'), backgroundColor: Colors.green),
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

  Future<void> _deleteWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout'),
        content: Text('Are you sure you want to delete "${widget.workout.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.deleteWorkout(widget.workout.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout deleted'), backgroundColor: Colors.red));
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
                  const Text('Edit Workout ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),

            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : Form(
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
                                child: const Icon(Icons.edit, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Edit Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  // Text('ID: ${widget.workout.id}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
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
                              const Text('Update Program', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 20),
                              _buildLabel('Program name'),
                              _buildTextField(controller: _programNameController, hintText: 'Leg Workout'),
                              const SizedBox(height: 16),
                              _buildLabel('Goal'),
                              _buildDropdown(value: _selectedGoal, items: _goals, onChanged: (value) => setState(() => _selectedGoal = value!)),
                              const SizedBox(height: 16),
                              _buildLabel('Durations'),
                              GestureDetector(
                                onTap: _showAndroidTimerPicker,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${_durationController.text} mins', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      const Icon(Icons.timer, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
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
                            onPressed: _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDAD9FF),
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _deleteWorkout,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: const BorderSide(color: Colors.red, width: 2),
                            ),
                            child: const Text('Delete Record', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _buildExerciseForm(EditExerciseForm exercise, int index) {
    final bodyParts = ['Leg', 'Chest', 'Arm', 'Back', 'Shoulder', 'Abdominal Muscle'];
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
          _buildDropdown(value: exercise.selectedBodyPart, items: bodyParts, enabled: false, onChanged: (v) {}),
          const SizedBox(height: 16),

          _buildLabel('Exercise Images (Multiple)'),
          _buildUploadField(
            exercise.imageUrls.isEmpty ? 'Select images' : '${exercise.imageUrls.length} images selected',
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
                  final path = exercise.imageUrls[imgIndex];
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: path.startsWith('http') ? NetworkImage(path) as ImageProvider : FileImage(File(path)), 
                            fit: BoxFit.cover
                          ),
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
}

class EditExerciseForm {
  final String? exerciseId;
  final TextEditingController exerciseNameController;
  String selectedBodyPart;
  List<String> imageUrls;
  int sets;
  int repeat;
  final TextEditingController instructionsController;

  EditExerciseForm({
    this.exerciseId,
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
