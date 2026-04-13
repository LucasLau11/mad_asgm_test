//flutter pub add sqflite
//flutter pub add uuid
//flutter pub add path_provider
// heart rate monitor (YH)
// flutter pub add camera
// flutter pub add permission_handler
//workout program module (TW)
//flutter pub add google_ml_kit
//flutter pub add image_picker


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/exercise_controller.dart';
import 'controllers/pedometer_controller.dart';
import 'controllers/location_controller.dart';
import 'views/login_screen.dart';

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
        home: const LoginScreen(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  static const List<Widget> _pages = [
    HealthMonitorPage(),   //TODO jim eh page
    WorkoutProgramPage(),
    ExerciseListView(),
    HealthMonitorPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FitPulseHeader(),
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
          BottomNavigationBarItem(icon: Icon(Icons.rounded_corner), label: 'Jim'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workout'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'Exercise'),
          BottomNavigationBarItem(icon: Icon(Icons.monitor_heart), label: 'Health'),
        ],
      ),
    );
  }
}

class FitPulseHeader extends StatelessWidget implements PreferredSizeWidget {
  const FitPulseHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/fitpulse.png',
            width: 42,
            height: 42,
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: const Text(
              'FitPulse',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFEEEEEE), height: 1),
      ),
    );
  }
}
