//flutter pub add sqflite
//flutter pub add uuid
//flutter pub add path_provider
// heart rate monitor (YH)
// flutter pub add camera
// flutter pub add permission_handler
//workout program module (TW)
//flutter pub add google_ml_kit

import 'package:flutter/material.dart';
import 'views/health_monitor_page.dart';
import 'views/workout_program_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitPulse',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 3; // start on health(for now)

  // page navigation
  final List<Widget> _pages = [
    const Placeholder(), // TODO replace with profile
    const WorkoutProgramPage(),
    const Placeholder(), // TODO replace with exercise
    const HealthMonitorPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack allows all pages to be alive without needing to reload when switching tabs
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      
      bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF9FA8DA),
          unselectedItemColor: Colors.grey,
          onTap: (index){
            // pop back to root if user taps any nav tab while on a subpage
            Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
            setState(() {
              _currentIndex = index;
            });

          },
          items: [
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
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
              icon: Icon(Icons.favorite_border),
              label: 'Health',
            ),
          ]
      ),

    );
  }
}
