import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_state.dart';
import 'onboarding.dart'; 
import 'sign_in.dart';
import 'dashboard.dart'; 
import 'update_password.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); 

  try {
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!, 
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!, 
    );

    final appState = AppState();
    await appState.initRevenueCat();

    runApp(
      ChangeNotifierProvider.value(
        value: appState,
        child: const OmniPlateApp(),
      ),
    );
  } catch (e) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text('ΣΦΑΛΜΑ: $e', style: const TextStyle(color: Colors.red))))));
  }
}

class OmniPlateApp extends StatelessWidget {
  const OmniPlateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniPlate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF2B2D31),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

Widget omniLogo() {
  return Container(
    width: 90,
    height: 90,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF2B2D31),
      border: Border.all(color: Colors.white, width: 4),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
      ]
    ),
    child: Center(
      child: Container(
        width: 55,
        height: 55,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFED6058)),
      ),
    ),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    
    // Ακούμε για επιστροφές από emails ή google
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UpdatePasswordScreen()));
        }
      } else if (event == AuthChangeEvent.signedIn && session != null) {
        _checkProfileAndRoute(session);
      }
    });

    // Αρχικός έλεγχος κατά το άνοιγμα
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return; 
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('remember_me') == true) {
          await _checkProfileAndRoute(session);
        } else {
          await Supabase.instance.client.auth.signOut();
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignUpScreen()));
        }
      } else {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignUpScreen()));
      }
    });
  }

  // Η καρδιά του Routing: Ελέγχει αν έχεις τελειώσει το Onboarding
  Future<void> _checkProfileAndRoute(Session session) async {
    try {
      final profileData = await Supabase.instance.client
          .from('users')
          .select('age, weight')
          .eq('id', session.user.id)
          .maybeSingle();

      if (!mounted) return;

      if (profileData == null || profileData['age'] == null || profileData['weight'] == null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OnboardingScreen()));
      } else {
        await context.read<AppState>().syncWithSupabase();
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
        }
      }
    } catch (e) {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignUpScreen()));
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            omniLogo(),
            const SizedBox(height: 20),
            const Text('OmniPlate', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500, letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _isPasswordHidden = true;
  bool _isLoading = false; 
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Πιάνει το verification link και το google login αν πατηθούν ενώ είμαστε εδώ
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        _checkProfileAndRoute(data.session!);
      }
    });
  }

  Future<void> _checkProfileAndRoute(Session session) async {
    final profileData = await Supabase.instance.client
        .from('users').select('age, weight').eq('id', session.user.id).maybeSingle();

    if (!mounted) return;

    if (profileData == null || profileData['age'] == null || profileData['weight'] == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OnboardingScreen()));
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', true);
      await context.read<AppState>().syncWithSupabase();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return; 

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        // ΝΕΟ: Αποθηκεύει κατευθείαν ότι ο χρήστης θέλει να μείνει συνδεδεμένος
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', true);

        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const OnboardingScreen())
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.omniplate://login-callback',
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
                const Text('Join OmniPlate', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Track your health with AI.', style: TextStyle(color: subTextColor, fontSize: 14)),
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
                        if (value == null || value.isEmpty) return 'Please enter an email';
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
                        if (value == null || value.isEmpty) return 'Please enter a password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('SIGN UP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
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
                    const Text('Already have an account? ', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignInScreen())),
                      child: const Text('Sign In', style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.bold)),
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