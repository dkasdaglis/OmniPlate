import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'dashboard.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isAnalyzing = true; 

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        _controller.stop(); 
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF2B2D31);
    const accentColor = Color(0xFFED6058);
    const cardColor = Color(0xFF1E1F22);

    // ΤΡΑΒΑΜΕ ΤΑ ΔΕΔΟΜΕΝΑ ΑΠΟ ΤΟΝ ΕΓΚΕΦΑΛΟ
    final appState = context.watch<AppState>();
    final dailyGoal = appState.dailyGoal;
    final weight = appState.weight;
    
    // ΕΠΑΓΓΕΛΜΑΤΙΚΟΣ ΥΠΟΛΟΓΙΣΜΟΣ (Health Data Engineering)
    final protein = (weight * 2.2).round(); // 2.2g ανά κιλό
    final fats = (weight * 1.0).round();    // 1.0g ανά κιλό
    
    // Μετατροπή σε θερμίδες για να βρούμε τι περισσεύει για υδατάνθρακες
    final proteinKcal = protein * 4;
    final fatsKcal = fats * 9;
    final remainingKcalForCarbs = dailyGoal - proteinKcal - fatsKcal;
    
    final carbs = remainingKcalForCarbs > 0 ? (remainingKcalForCarbs / 4).round() : 0;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: _isAnalyzing 
            ? _buildLoadingState(accentColor) 
            : _buildResultsState(accentColor, cardColor, dailyGoal, protein, carbs, fats),
      ),
    );
  }

  Widget _buildLoadingState(Color accentColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RotationTransition(
          turns: _controller,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 10,
                )
              ]
            ),
            child: const Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFED6058)),
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 60),
        const Text(
          'Analyzing Biometrics...',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Calculating BMR AND\nTDEE FORMULAS',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildResultsState(Color accentColor, Color cardColor, int calories, int protein, int carbs, int fats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 80),
          const SizedBox(height: 24),
          const Text(
            'Plan Generated!',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Based on your profile, here is your personalized daily target.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 40),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  '$calories',
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                ),
                const Text('Kcal / day', style: TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _macroItem('Protein', '${protein}g', const Color(0xFFED6058)),
                    _macroItem('Carbs', '${carbs}g', const Color(0xFF4CAF50)),
                    _macroItem('Fats', '${fats}g', const Color(0xFFFFC107)),
                  ],
                )
              ],
            ),
          ),
          
          const SizedBox(height: 60),
          
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('START TRACKING', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}