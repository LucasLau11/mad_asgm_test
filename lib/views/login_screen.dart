import 'package:flutter/material.dart';
import 'package:mad_asgm/main.dart';
import '../services/database/heart_rate_database_service.dart';
import '../widgets/shared_widgets.dart';
import 'signup_screen.dart';
import 'package:provider/provider.dart';
import '../controllers/exercise_controller.dart';
import '../models/analytic_model/analytics_app_state.dart';



class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dbService = DatabaseService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  // --------------- some change
  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = await _dbService.loginUser(
      username: _usernameController.text,
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid username or password.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // ← Reload exercises scoped to the newly logged-in user
    await Provider.of<ExerciseController>(context, listen: false)
        .reloadForCurrentUser();

    // Seed analytics state with the logged-in user's data
    await Provider.of<AnalyticsAppState>(context, listen: false)
        .onUserLoggedIn();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  // void _handleLogin() async {
  //   if (!_formKey.currentState!.validate()) return;
  //   setState(() => _isLoading = true);
  //
  //   final user = await _dbService.loginUser(
  //     username: _usernameController.text,
  //     password: _passwordController.text,
  //   );
  //
  //   setState(() => _isLoading = false);
  //   if (!mounted) return;
  //
  //   if (user == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: const Text('Invalid username or password.'),
  //         backgroundColor: Colors.redAccent,
  //         behavior: SnackBarBehavior.floating,
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //       ),
  //     );
  //     return;
  //   }
  //
  //   Navigator.pushReplacement(
  //     context,
  //     MaterialPageRoute(builder: (_) => const MainShell()),
  //   );
  // }

  // -------------- some change

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Image.asset(
                  'assets/images/fitpulse.png',
                  width: 100,
                  height: 100,
                ),

                const SizedBox(height: 16),

                Text(
                  'Login to Start Your Fitness Journey',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),

                const SizedBox(height: 32),

                FitPulseTextField(
                  controller: _usernameController,
                  hintText: 'Username',
                  prefixIcon: Icons.person_outline,
                  validator: (v) => (v == null || v.isEmpty) ? 'Please enter your username' : null,
                ),

                const SizedBox(height: 16),

                FitPulseTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textMuted, size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Please enter your password' : null,
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      final usernameController = TextEditingController();
                      final newPasswordController = TextEditingController();
                      final confirmPasswordController = TextEditingController();
                      bool obscureNew = true;
                      bool obscureConfirm = true;

                      showDialog(
                        context: context,
                        builder: (context) => StatefulBuilder(
                          builder: (context, setDialogState) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text(
                              'Reset Password',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Enter your username and a new password.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: usernameController,
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    prefixIcon: const Icon(Icons.person_outline),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: newPasswordController,
                                  obscureText: obscureNew,
                                  decoration: InputDecoration(
                                    labelText: 'New Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: confirmPasswordController,
                                  obscureText: obscureConfirm,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final username = usernameController.text.trim();
                                  final newPw = newPasswordController.text;
                                  final confirmPw = confirmPasswordController.text;

                                  if (username.isEmpty || newPw.isEmpty || confirmPw.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Please fill in all fields.'),
                                        backgroundColor: Colors.orange,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                    return;
                                  }

                                  if (newPw != confirmPw) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Passwords do not match.'),
                                        backgroundColor: Colors.redAccent,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                    return;
                                  }

                                  final success = await _dbService.resetPassword(
                                    username: username,
                                    newPassword: newPw,
                                  );

                                  if (!context.mounted) return;
                                  Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success
                                          ? 'Password reset successfully!'
                                          : 'Username not found.'),
                                      backgroundColor: success ? Colors.green : Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Text('Forgot Password ?',
                        style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ),

                const SizedBox(height: 8),

                FitPulsePrimaryButton(label: 'Login', isLoading: _isLoading, onPressed: _handleLogin),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                      child: Text('Sign Up',
                          style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}