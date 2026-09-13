import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'analyze.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late String selectedGoal;
  late String selectedGender;
  late String selectedActivity; 
  String selectedPace = 'Mid';

  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _goalWeightController;

  @override
  void initState() {
    super.initState();
    
    // Η οθόνη Onboarding ρωτάει τη μνήμη πριν εμφανίσει οτιδήποτε
    final appState = context.read<AppState>();
    
    selectedGoal = appState.goal;
    selectedGender = appState.gender;
    selectedActivity = appState.activityLevel;
    
    // Έξυπνη μετατροπή για να αφαιρεί το ".0" (π.χ. "65" αντί για "65.0")
    String weightText = appState.weight == appState.weight.toInt() ? appState.weight.toInt().toString() : appState.weight.toString();
    String heightText = appState.height == appState.height.toInt() ? appState.height.toInt().toString() : appState.height.toString();

    _ageController = TextEditingController(text: appState.age.toString());
    _weightController = TextEditingController(text: weightText);
    _heightController = TextEditingController(text: heightText);
    
    // Προτείνει αυτόματα -5 κιλά ως Goal Weight
    int goalWeight = (appState.weight - 5).toInt();
    _goalWeightController = TextEditingController(text: goalWeight.toString());
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _goalWeightController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      double weight = double.tryParse(_weightController.text) ?? 70.0;
      double height = double.tryParse(_heightController.text) ?? 180.0;
      int age = int.tryParse(_ageController.text) ?? 21;

      final appState = context.read<AppState>();
      
      appState.gender = selectedGender;
      appState.goal = selectedGoal;
      
      appState.updateUserData(
        newAge: age,
        newWeight: weight,
        newHeight: height,
        newActivity: selectedActivity,
      );

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AnalyzeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF2B2D31);
    const accentColor = Color(0xFFED6058);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_currentPage > 0) {
                            _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Text('Step ${_currentPage + 1} of 3', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(width: 24),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(flex: _currentPage + 1, child: Container(height: 4, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2)))),
                      Expanded(flex: 2 - _currentPage, child: Container(height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), 
                onPageChanged: (int page) => setState(() => _currentPage = page),
                children: [_buildStep1(), _buildStep2(), _buildStep3()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Text('What brings you to OmniPlate?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          const Text('Select your goal', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 20),
          _goalCard('Lose Weight', 'Burn fat & lean down', Icons.local_fire_department, selectedGoal == 'Lose Weight', 1),
          const SizedBox(height: 16),
          _goalCard('Maintain Weight', 'Stay fit & balanced', Icons.monitor_weight_outlined, selectedGoal == 'Maintain Weight', 1),
          const SizedBox(height: 16),
          _goalCard('Gain Muscle', 'Build strength & size', Icons.fitness_center, selectedGoal == 'Gain Muscle', 1),
          const SizedBox(height: 40),
          _proceedButton('PROCEED', _nextPage),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Text('Tell us about yourself', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          const Text('Personal Details', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 20),
          
          const Align(alignment: Alignment.centerLeft, child: Text('Age', style: TextStyle(color: Colors.white70, fontSize: 14))),
          const SizedBox(height: 8),
          _inputField(_ageController, isNumber: true),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(child: _genderButton('Male', Icons.male, selectedGender == 'Male')),
              const SizedBox(width: 16),
              Expanded(child: _genderButton('Female', Icons.female, selectedGender == 'Female')),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Weight', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    _inputField(_weightController, suffix: 'kg', isNumber: true),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Height', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    _inputField(_heightController, suffix: 'cm', isNumber: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _proceedButton('PROCEED', _nextPage),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Text('Fine-tune your plan!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          const Text('Activity Level', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 20),
          _goalCard('Sedentary', 'Mostly sitting', Icons.chair_alt, selectedActivity == 'Sedentary', 3),
          const SizedBox(height: 12),
          _goalCard('Light', '1-3 workouts/week', Icons.directions_walk, selectedActivity == 'Light', 3),
          const SizedBox(height: 12),
          _goalCard('Moderate', '3-5 workouts/week', Icons.sports_gymnastics, selectedActivity == 'Moderate', 3),
          const SizedBox(height: 12),
          _goalCard('Active', '6-7 workouts/week', Icons.fitness_center, selectedActivity == 'Active', 3),
          const SizedBox(height: 12),
          _goalCard('Very Active', 'Physical job or 2x training', Icons.local_fire_department, selectedActivity == 'Very Active', 3),
          
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Goal Weight', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    _inputField(_goalWeightController, suffix: 'kg', isNumber: true),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pace', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      height: 55,
                      decoration: BoxDecoration(color: const Color(0xFF1E1F22), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: ['Slow', 'Mid', 'Fast'].map((pace) {
                          bool isActive = selectedPace == pace;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => selectedPace = pace),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFED6058) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(pace, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _proceedButton('GENERATE PLAN', _nextPage),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _goalCard(String title, String subtitle, IconData icon, bool isActive, int step) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (step == 1) selectedGoal = title;
          if (step == 3) selectedActivity = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFED6058) : const Color(0xFF1E1F22),
          borderRadius: BorderRadius.circular(16),
          border: isActive ? null : Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? Colors.white : Colors.white70, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isActive ? Colors.white : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(color: isActive ? Colors.white70 : Colors.white54, fontSize: 13)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _genderButton(String title, IconData icon, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => selectedGender = title),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFED6058) : const Color(0xFF1E1F22),
          borderRadius: BorderRadius.circular(12),
          border: isActive ? null : Border.all(color: Colors.white12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: isActive ? Colors.white : Colors.white70, size: 32),
      ),
    );
  }

  Widget _inputField(TextEditingController controller, {String? suffix, bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))] : [],
      style: const TextStyle(color: Colors.white, fontSize: 18),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF1E1F22),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Colors.white54),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _proceedButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFED6058),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
      ),
    );
  }
}