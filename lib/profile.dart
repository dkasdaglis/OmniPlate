import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'app_state.dart';
import 'sign_in.dart'; 
import 'onboarding.dart'; // Απαραίτητο για το Retake Onboarding

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _activityLevel;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _activityLevel = appState.activityLevel;
    _ageController = TextEditingController(text: appState.age.toString());
    
    // Μετατροπή προβολής ανάλογα με το Metric ή Imperial
    double displayWeight = appState.isMetric ? appState.weight : appState.weight * 2.20462;
    double displayHeight = appState.isMetric ? appState.height : appState.height * 0.393701;

    String weightText = displayWeight == displayWeight.toInt() ? displayWeight.toInt().toString() : displayWeight.toStringAsFixed(1);
    String heightText = displayHeight == displayHeight.toInt() ? displayHeight.toInt().toString() : displayHeight.toStringAsFixed(1);
    
    _weightController = TextEditingController(text: weightText);
    _heightController = TextEditingController(text: heightText);
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF2B2D31);
    const cardColor = Color(0xFF1E1F22);
    const accentColor = Color(0xFFED6058);

    // Διαβάζουμε το AppState για το σύστημα μονάδων
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Personal Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: cardColor,
              child: Icon(Icons.person, size: 60, color: accentColor),
            ),
            const SizedBox(height: 32),
            
            _buildNumberField('Age', _ageController, '', cardColor),
            const SizedBox(height: 16),
            // Δυναμικό suffix (kg ή lbs)
            _buildNumberField('Weight', _weightController, appState.isMetric ? 'kg' : 'lbs', cardColor),
            const SizedBox(height: 16),
            // Δυναμικό suffix (cm ή in)
            _buildNumberField('Height', _heightController, appState.isMetric ? 'cm' : 'in', cardColor),
            const SizedBox(height: 16),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Activity Level', style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _activityLevel,
                      dropdownColor: cardColor,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      onChanged: (String? newValue) {
                        setState(() {
                          _activityLevel = newValue!; 
                        });
                      },
                      items: <String>['Sedentary', 'Light', 'Moderate', 'Active', 'Very Active']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  int newAge = int.tryParse(_ageController.text) ?? 21;
                  double inputWeight = double.tryParse(_weightController.text) ?? 78.0;
                  double inputHeight = double.tryParse(_heightController.text) ?? 182.0;

                  // Επαναφορά σε kg/cm για αποθήκευση στον εγκέφαλο
                  double newWeight = appState.isMetric ? inputWeight : inputWeight / 2.20462;
                  double newHeight = appState.isMetric ? inputHeight : inputHeight / 0.393701;

                  context.read<AppState>().updateUserData(
                    newAge: newAge,
                    newWeight: newWeight,
                    newHeight: newHeight,
                    newActivity: _activityLevel,
                  );

                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // ΝΕΟ: Κουμπί για επαναφορά στο Onboarding
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const OnboardingScreen())
                  );
                },
                icon: const Icon(Icons.restart_alt, color: accentColor),
                label: const Text('RETAKE ONBOARDING', style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: accentColor, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            
            const SizedBox(height: 40), 

            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const SignInScreen()),
                      (route) => false, 
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('SIGN OUT', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller, String suffix, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true), 
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            suffixText: suffix, 
            suffixStyle: const TextStyle(color: Colors.white54, fontSize: 16),
            filled: true,
            fillColor: cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}