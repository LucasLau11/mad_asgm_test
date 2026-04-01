//flutter pub add sqflite
//flutter pub add uuid
//flutter pub add path_provider
// heart rate monitor (YH)
// flutter pub add camera
// flutter pub add permission_handler
//workout program module (TW)
//flutter pub add google_ml_kit

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/exercise_controller.dart';
import 'controllers/pedometer_controller.dart';
import 'controllers/location_controller.dart';

// Your module views
import 'views/exercise_list_view.dart';

// Friend's module views
import 'views/workout_program_page.dart';
import 'views/health_monitor_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExerciseController()),
        ChangeNotifierProvider(create: (_) => PedometerController()),
        ChangeNotifierProvider(create: (_) => LocationController()),
      ],
      child: MaterialApp(
        title: 'Fitness Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.purple,
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          fontFamily: 'SF Pro Display',
          textTheme: const TextTheme(
            bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
            bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C6FDC),
          ),
        ),
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  // Keep pages alive when switching tabs
  static const List<Widget> _pages = [
    ExerciseListView(),
    WorkoutProgramPage(),     // Friend's workout module
    ExerciseListView(),       // Your module
    HealthMonitorPage(),      // Friend's health monitor module
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF7C6FDC),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.rounded_corner),
            label: 'Jim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: 'Exercise',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: 'Health',
          ),
        ],
      ),
    );
  }
}
