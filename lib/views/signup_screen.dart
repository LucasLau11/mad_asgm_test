import 'package:flutter/material.dart';
import '../services/database/heart_rate_database_service.dart';
import '../widgets/shared_widgets.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _dbService = DatabaseService();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  double _passwordStrength = 0;
  String _strengthLabel = '';
  Color _strengthColor = Colors.transparent;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _checkStrength(String v) {
    double s = 0;
    if (v.length >= 8) s += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(v)) s += 0.25;
    if (RegExp(r'[0-9]').hasMatch(v)) s += 0.25;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) s += 0.25;
    String label; Color color;
    if (s <= 0.25)      { label = 'Weak';     color = Colors.red; }
    else if (s <= 0.50) { label = 'Normal';     color = Colors.orange; }
    else if (s <= 0.75) { label = 'Good';     color = Colors.lightGreen; }
    else                { label = 'Strong'; color = AppColors.green; }
    setState(() { _passwordStrength = s; _strengthLabel = label; _strengthColor = color; });
  }

  void _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = await _dbService.registerUser(
      username: _usernameController.text,
      password: _passwordController.text,
      email: _emailController.text,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Username already taken. Please choose another.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account created! Welcome, ${user.username}'),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    //Success
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

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

                Text('Create Your FitPulse Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),

                const SizedBox(height: 32),

                // Username
                FitPulseTextField(
                  controller: _usernameController,
                  keyboardType: TextInputType.name,
                  hintText: 'Username',
                  prefixIcon: Icons.person_outline,
                  validator: (v) => (v == null || v.isEmpty) ? 'Please enter a username' : null,
                ),

                const SizedBox(height: 16),

                // Email
                FitPulseTextField(
                  controller: _emailController,
                  hintText: 'Email Address',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter your email';
                    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return 'Enter a valid email';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password
                FitPulseTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  onChanged: _checkStrength,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textMuted, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter a password';
                    if (v.length < 8) return 'Password must be at least 8 characters';
                    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Must contain at least one capital letter';
                    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Must contain at least one number';
                    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) return 'Must contain at least one symbol';
                    return null;
                  },
                ),

                if (_passwordStrength > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: _passwordStrength,
                            backgroundColor: const Color(0xFFDDE3ED),
                            valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                            minHeight: 4,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Text(_strengthLabel,
                          style: TextStyle(fontSize: 11, color: _strengthColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Confirm Password
                FitPulseTextField(
                  controller: _confirmController,
                  hintText: 'Confirm Password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textMuted, size: 20),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm your password';
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                FitPulsePrimaryButton(label: 'Create Account', isLoading: _isLoading, onPressed: _handleSignup),

                const SizedBox(height: 24),

                //Terms & service statement
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    children: [
                      const TextSpan(text: 'By signing up you agree to our '),

                      TextSpan(text: 'Terms of Service',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),

                      const TextSpan(text: ' and '),

                      TextSpan(text: 'Privacy Policy',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: Text('Login',
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

