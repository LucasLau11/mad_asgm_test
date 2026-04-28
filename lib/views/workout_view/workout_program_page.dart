import 'package:flutter/material.dart';
import '../../controllers/workout_controller.dart';
import '../../services/database/heart_rate_database_service.dart';
import '../../models/workout_model/workout_model.dart';
import 'workout_program_add_page.dart';
import 'manage_workout_page.dart';
import 'workout_detail_page.dart';

class WorkoutProgramPage extends StatefulWidget {
  const WorkoutProgramPage({Key? key}) : super(key: key);

  @override
  State<WorkoutProgramPage> createState() => _WorkoutProgramPageState();
}

class _WorkoutProgramPageState extends State<WorkoutProgramPage> {
  final WorkoutController _controller = WorkoutController();
  final TextEditingController _searchController = TextEditingController();

  List<Workout> _allWorkouts = [];
  List<Workout> _filteredWorkouts = [];
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialLoad();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initialLoad() async {
    // await _controller.seedDatabaseIfNeeded();
    await _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final currentUserId = DatabaseService.currentUserId;
      final workouts = await _controller.getWorkoutsByUserId(currentUserId);

      if (mounted) {
        setState(() {
          _allWorkouts = workouts.reversed.toList();
          _filteredWorkouts = _allWorkouts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading workouts: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();

    final results = _allWorkouts.where((workout) {
      return workout.name.toLowerCase().contains(query) ||
          workout.description.toLowerCase().contains(query) ||
          workout.difficulty.toLowerCase().contains(query);
    }).toList();

    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredWorkouts = query.isEmpty ? _allWorkouts : results;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _filteredWorkouts = _allWorkouts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          // This line is the key: it aligns all children to the left
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // This acts as your top spacing/header area
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                      'Workout Program',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface
                      )
                  ),
                  const SizedBox(height: 4),
                  Text(
                      _getFormattedDate(),
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,

                      )
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    if (_isSearching)
                    // Shadow when searching (Blue)
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    else if (Theme.of(context).brightness == Brightness.light)
                    // Shadow when NOT searching but in Light Mode
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],

                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: _isSearching ? Colors.blue[700] : Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(hintText: 'Search workouts...', border: InputBorder.none),
                      ),
                    ),
                    if (_isSearching)
                      IconButton(
                        icon:  Icon(Icons.clear, color: Colors.grey[600]),
                        onPressed: _clearSearch,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Main Content Area
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredWorkouts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isSearching ? Icons.search_off : Icons.fitness_center, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(_isSearching ? 'No workouts found' : 'No workouts available', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filteredWorkouts.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildWorkoutCard(_filteredWorkouts[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageWorkoutsPage()));
                _loadWorkouts();
              },
              child: const Text("Manage"),
            ),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddWorkoutProgramPage()));
                _loadWorkouts();
              },
              child: const Text("+ Add"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => WorkoutDetailPage(workout: workout)));
        _loadWorkouts();
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Color(int.parse(workout.color)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(workout.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(workout.difficulty, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(workout.description, style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}
