import 'package:flutter/material.dart';
import 'dart:io';
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
  late String focusBodyPart;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final Map<String, String> _exerciseToBodyPart = {
    'Squat': 'Leg',
    'Sit-up': 'Abdominal Muscle',
    'Push-ups': 'Chest',
  };

  final List<String> _fallbackImages = [
    'https://images.unsplash.com/photo-1566241142559-40e1dab266c6?w=800&q=80',
    'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=800&q=80',
    'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&q=80',
  ];

  @override
  void initState() {
    super.initState();
    sets = widget.exercise.sets;
    repeat = widget.exercise.reps;
    // Get focus body part from the map or default to 'Other'
    focusBodyPart = _exerciseToBodyPart[widget.exercise.name] ?? 'Other';
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> displayImages = widget.exercise.imageUrls.isNotEmpty 
        ? widget.exercise.imageUrls 
        : _fallbackImages;

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
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.exercise.name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Container(
                    height: 250,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          onPageChanged: (int page) => setState(() => _currentPage = page),
                          itemCount: displayImages.length,
                          itemBuilder: (context, index) {
                            final path = displayImages[index];

                            // Check if path is a URL or a Local File
                            if (path.startsWith('http')) {
                              return Image.network(
                                path,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                                errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                              );
                            } else {
                              return Image.file(
                                File(path),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                              );
                            }
                          },
                        ),
                        
                        if (_currentPage > 0)
                          Positioned(
                            left: 8, top: 0, bottom: 0,
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                                  onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                ),
                              ),
                            ),
                          ),

                        if (_currentPage < displayImages.length - 1)
                          Positioned(
                            right: 8, top: 0, bottom: 0,
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                                  onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                ),
                              ),
                            ),
                          ),

                        Positioned(
                          bottom: 15, left: 0, right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              displayImages.length,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 8, height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.5)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _buildControlRow('Sets', sets),
                  const SizedBox(height: 12),
                  _buildControlRow('Repeat', repeat),
                  const SizedBox(height: 12),
                  _buildControlRow('Focus Body Part', focusBodyPart),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 16),
                        Text(widget.exercise.instructions, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5)),
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

  Widget _buildControlRow(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Label on the left
          Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[700])),

          const SizedBox(width: 16), // Add some spacing between label and value

          // Value on the right
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.end, // Keep the text aligned to the right
              overflow: TextOverflow.ellipsis, // This adds the "..."
              maxLines: 1, // Ensure it stays on one line
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87
              ),
            ),
          ),
        ],
      ),
    );
  }
}
