//flutter pub add sqflite
//flutter pub add uuid
//flutter pub add path_provider
// heart rate monitor (YH)
// flutter pub add camera
// flutter pub add permission_handler
//workout program module (TW)
//flutter pub add google_ml_kit
//flutter pub add image_picker
// background step tracking
// flutter pub add flutter_foreground_task

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'controllers/exercise_controller.dart';
import 'controllers/pedometer_controller.dart';
import 'controllers/location_controller.dart';
import 'models/analytic_model/analytics_app_state.dart';
import 'services/database/heart_rate_database_service.dart';
import 'services/step_tracking_service.dart';
import 'views/login_screen.dart';

import 'views/exercise_view/exercise_list_view.dart';
import 'views/workout_view/workout_program_page.dart';
import 'views/heart_rate_view/health_monitor_page.dart';
import 'views/analytic_view/analytics_view.dart';

// MUST be top-level in main.dart with @pragma so tree-shaker keeps it.
// References StepTaskHandler (public class in step_tracking_service.dart).
@pragma('vm:entry-point')
void startStepTaskCallback() {
  FlutterForegroundTask.setTaskHandler(StepTaskHandler());
}

final AnalyticsAppState analyticsAppState = AnalyticsAppState();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await analyticsAppState.loadFromStorage();

  // Configure foreground service options before runApp.
  // The service is actually started in PedometerController.startAutoDetect()
  // which is called from ExerciseListView.initState().
  StepTrackingService.init();

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
        ChangeNotifierProvider<AnalyticsAppState>.value(value: analyticsAppState),
      ],
      child: Consumer<AnalyticsAppState>(
        builder: (context, analyticsState, _) {
          return MaterialApp(
            title: 'Fitness Tracker',
            debugShowCheckedModeBanner: false,
            themeMode: analyticsState.darkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.purple,
              scaffoldBackgroundColor: Colors.white,
              fontFamily: 'SF Pro Display',
              textTheme: const TextTheme(
                bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
                bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF7C6FDC),
                brightness: Brightness.light,
                surface: Colors.white,
                onSurface: Colors.black87,
                onSurfaceVariant: Colors.grey,
              ),
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.all(Colors.white),
                trackColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                      ? const Color(0xFF4CD964)
                      : Colors.grey.shade400,
                ),
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF121212),
              primarySwatch: Colors.purple,
              fontFamily: 'SF Pro Display',
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                foregroundColor: Colors.grey,
                elevation: 0,
              ),
              cardColor: const Color(0xFF1E1E1E),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
                bodyMedium: TextStyle(fontSize: 14, color: Colors.white),
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF7C6FDC),
                brightness: Brightness.dark,
                surface: const Color(0xFF1E1E1E),
                onSurface: Colors.white,
                onSurfaceVariant: Colors.grey,
              ),
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.all(Colors.white),
                trackColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                      ? const Color(0xFF4CD964)
                      : Colors.grey.shade600,
                ),
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              ),
            ),
            home: const SplashRoute(),
          );
        },
      ),
    );
  }
}

class SplashRoute extends StatefulWidget {
  const SplashRoute({Key? key}) : super(key: key);
  @override
  State<SplashRoute> createState() => _SplashRouteState();
}

class _SplashRouteState extends State<SplashRoute> {
  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final user = await DatabaseService().tryRestoreSession();
    if (!mounted) return;
    if (user != null) {
      await Provider.of<ExerciseController>(context, listen: false).reloadForCurrentUser();
      await Provider.of<AnalyticsAppState>(context, listen: false).onUserLoggedIn();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/fitpulse.png', width: 100, height: 100),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C6FDC)),
              strokeWidth: 2,
            ),
          ],
        ),
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
    AnalyticsView(),
    WorkoutProgramPage(),
    ExerciseListView(),
    HealthMonitorPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: const FitPulseHeader(),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF7C6FDC),
        unselectedItemColor: Colors.grey,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Analytics'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/fitpulse.png', width: 42, height: 42),
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
        child: Container(color: dividerColor, height: 1),
      ),
    );
  }
}