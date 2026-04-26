import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../controllers/workout_controller.dart';
import '../../models/workout_model/workout_model.dart';
import '../../models/workout_model/workout_exercise_model.dart';

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
  late String? _previewImagePath;
  final List<String> _goals = ['Strength', 'Cardio', 'Flexibility', 'Weight Loss', 'Muscle Gain'];
  final List<String> _difficulties = ['Beginner', 'Intermediate', 'Advanced'];

  // Exercise library mapping for auto-select
  final Map<String, String> _exerciseToBodyPart = {
    'Squat': 'Leg',
    'Jumping Jack': 'Full Body',
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
    'Jumping Jack': '1. Stand upright with your feet together and arms at your sides.\n2. Jump while spreading your legs shoulder-width apart and raising your arms overhead.\n3. Quickly reverse the movement by jumping back to the starting position.\n4. Repeat in a steady rhythm while keeping your core engaged.',
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
    _selectedGoal = widget.workout.goal;
    _selectedDifficulty = widget.workout.difficulty;
    _previewImagePath = widget.workout.imageUrl;
    _loadExercises();
  }
  Future<void> _pickPreviewImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final int fileSize = await file.length();

        if (fileSize > 2 * 1024 * 1024) { // 2MB Limit
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image must be less than 2MB'), backgroundColor: Colors.orange),
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
          goal: _selectedGoal,
          description: '${_exercises.length} exercises - ${_durationController.text} min',
          exerciseCount: _exercises.length,
          durationMinutes: int.tryParse(_durationController.text) ?? 30,
          difficulty: _selectedDifficulty,
          color: widget.workout.color,
          imageUrl: _previewImagePath ?? '',
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

        // Navigate back with success result BEFORE showing SnackBar
        if (!mounted) return;
        Navigator.pop(context, true); // Return true for success

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _controller.deleteWorkout(widget.workout.id);

        // Navigate back with delete result BEFORE showing SnackBar
        if (!mounted) return;
        Navigator.pop(context, 'deleted'); // Return 'deleted' to indicate deletion

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:  Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface, size: 28),
                  ),
                  const SizedBox(width: 16),
                   Text('Edit Workout ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
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
                                child:  Icon(Icons.edit, color: Theme.of(context).colorScheme.surface, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   Text('Edit Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                                  // Text('ID: ${widget.workout.id}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16) ,
                            boxShadow: [
                          BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                          spreadRadius: 2,
                        ),
                      ],),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text('Update Program', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                              const SizedBox(height: 20),
                              _buildLabel('Program name'),
                              _buildTextField(controller: _programNameController, hintText: 'Leg Workout'),
                              const SizedBox(height: 16),
                              _buildLabel('Goal'),
                              _buildDropdown(value: _selectedGoal, items: _goals, onChanged: (value) => setState(() => _selectedGoal = value!)),
                              const SizedBox(height: 16),
                              _buildLabel('Durations (Estimated in mins)'),
                              GestureDetector(
                                onTap: _showAndroidTimerPicker,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${_durationController.text} mins', style:  TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                                       Icon(Icons.timer, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                              const SizedBox(height: 8),
                              _previewImagePath != null && _previewImagePath!.isNotEmpty
                                  ? Stack(
                                children: [
                                  Container(
                                    height: 160,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        // Logic to handle both local file paths and assets
                                        image: _previewImagePath!.startsWith('assets/')
                                            ? AssetImage(_previewImagePath!) as ImageProvider
                                            : FileImage(File(_previewImagePath!)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _previewImagePath = ''), // Clear to use fallback
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        child:  Icon(Icons.close, color: Theme.of(context).colorScheme.surface, size: 20),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                                  : _buildUploadField(
                                'Tap to select preview image',
                                Icons.upload,
                                _pickPreviewImage, // Now calls the function
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Text('Exercise(s)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
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
                              foregroundColor: Theme.of(context).colorScheme.onSurface,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      // High-contrast text color for both modes
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      // Improved validator with trim() to prevent empty spaces
      validator: (value) => (value == null || value.trim().isEmpty) ? 'This field is required' : null,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
        filled: true,
        // Uses the same background color logic you had before
        fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

        // Normal state border
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent),
        ),

        // When user is typing
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),

        // RED border when validation fails (fixes your issue)
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),

        // RED border when validation fails and user is still typing
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),

        // Style for the "Required" text below the box
        errorStyle: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDropdown({required String value, required List<String> items, required ValueChanged<String?> onChanged, bool enabled = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: enabled ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4) : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: enabled ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: enabled ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant),
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
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(text, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)), Icon(icon, color: Colors.grey[700])]),
      ),
    );
  }

  Widget _buildExerciseForm(EditExerciseForm exercise, int index) {
    final bodyParts = ['Leg', 'Chest', 'Arm', 'Back', 'Shoulder', 'Full Body'];
    final exerciseNames = _exerciseToBodyPart.keys.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16),
        boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 15,
          offset: const Offset(0, 5),
          spreadRadius: 2,
        ),
      ],),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_exercises.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Exercise ${index + 1}', style:  TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
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
                            child:  Icon(Icons.close, color: Theme.of(context).colorScheme.surface, size: 14),
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
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(onTap: onDecrement, child:  Icon(Icons.remove, size: 20, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(width: 16),
          Text('$value', style:  TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(width: 16),
          GestureDetector(onTap: onIncrement, child:  Icon(Icons.add, size: 20, color: Theme.of(context).colorScheme.onSurface)),
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
