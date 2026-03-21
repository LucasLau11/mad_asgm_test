import 'package:flutter/material.dart';
import '../models/workout_exercise_model.dart';

class ExerciseDetailPage extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailPage({
    Key? key,
    required this.exercise,
  }) : super(key: key);

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  late int sets;
  late int repeat;

  @override
  void initState() {
    super.initState();
    sets = widget.exercise.sets;
    repeat = widget.exercise.reps;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header with Back Button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.exercise.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Video/Image Placeholder
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFB8D4E8),
                          const Color(0xFF7BA5C9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_circle_outline,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.exercise.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Sets Control
                  _buildControlRow('Sets', sets, () {
                    if (sets > 1) setState(() => sets--);
                  }, () {
                    setState(() => sets++);
                  }),

                  const SizedBox(height: 12),

                  // Repeat Control
                  _buildControlRow('Repeat', repeat, () {
                    if (repeat > 1) setState(() => repeat--);
                  }, () {
                    setState(() => repeat++);
                  }),

                  const SizedBox(height: 20),

                  // Instructions Section
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
                          'Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.exercise.instructions,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlRow(String label, int value, VoidCallback onMinus, VoidCallback onPlus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          Row(
            children: [
              _buildControlButton(Icons.remove, onMinus),
              const SizedBox(width: 20),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 20),
              _buildControlButton(Icons.add, onPlus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.grey[700], size: 18),
      ),
    );
  }
}