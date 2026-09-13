import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'dashboard.dart'; 
import 'main.dart';
import 'onboarding.dart'; // Απαραίτητο για να ξέρει πού να στείλει τον χρήστη

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isPasswordHidden = true;
  bool _isLoading = false; 
  bool _rememberMe = true; 
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', _rememberMe);

        if (mounted) {
          await context.read<AppState>().syncWithSupabase();
        }

        // ΝΕΟΣ ΕΛΕΓΧΟΣ: Ρωτάμε αν υπάρχουν συγκεκριμένα δεδομένα (ηλικία, βάρος)
        final profileData = await Supabase.instance.client
            .from('users')
            .select('age, weight')
            .eq('id', response.user!.id)
            .maybeSingle();

        if (mounted) {
          // Αν δεν βρει γραμμή, Ή αν η γραμμή υπάρχει αλλά το age/weight είναι null (άδεια)
          if (profileData == null || profileData['age'] == null || profileData['weight'] == null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          }
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message), backgroundColor: Colors.redAccent));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address first.'), backgroundColor: Colors.redAccent)
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset link sent to your email!'), backgroundColor: Color(0xFF4CAF50))
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${error.toString()}'), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.omniplate://login-callback', // ΑΛΛΑΓΗ ΕΔΩ
      );
    } catch (e) {
      // ...
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Colors.white;
    const subTextColor = Colors.white70;
    const fieldColor = Color(0xFF1E1F22);
    const accentColor = Color(0xFFED6058);

    return Scaffold(
      backgroundColor: const Color(0xFF2B2D31),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                omniLogo(), 
                const SizedBox(height: 24),
                const Text('Welcome Back', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Sign in to continue to OmniPlate', style: TextStyle(color: subTextColor, fontSize: 14)),
                const SizedBox(height: 40),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Email', style: TextStyle(color: subTextColor, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'your@email.com',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: fieldColor,
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your email';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Password', style: TextStyle(color: subTextColor, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _isPasswordHidden,
                      style: const TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: '***********',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: fieldColor,
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white54),
                          onPressed: () => setState(() => _isPasswordHidden = !_isPasswordHidden),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your password';
                        return null; 
                      },
                    ),
                  ],
                ),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text('Forgot Password?', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 8),

                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (value) => setState(() => _rememberMe = value ?? true),
                        activeColor: accentColor,
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Keep me signed in', style: TextStyle(color: subTextColor, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('SIGN IN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                ),
                const SizedBox(height: 30),

                Row(
                  children: const [
                    Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Or', style: TextStyle(color: Colors.white54, fontSize: 14))),
                    Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                  ],
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: fieldColor,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.g_mobiledata, color: Colors.white, size: 32),
                    label: const Text('Continue with Google', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? ", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
                      child: const Text('Sign Up', style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}