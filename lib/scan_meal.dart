import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:provider/provider.dart';
import 'app_state.dart';

class ScanMealScreen extends StatefulWidget {
  const ScanMealScreen({super.key});

  @override
  State<ScanMealScreen> createState() => _ScanMealScreenState();
}

class _ScanMealScreenState extends State<ScanMealScreen> {
  Uint8List? _imageBytes;
  bool _isScanning = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
        _analyzeImage(bytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _analyzeImage(Uint8List bytes) async {
    setState(() {
      _isScanning = true;
    });

    try {
      final String base64Image = base64Encode(bytes);

      final response = await Supabase.instance.client.functions.invoke(
        'analyze_meal',
        body: {'imageBase64': base64Image},
      );

      if (response.status != 200) {
        throw Exception('Server Error: ${response.status}');
      }

      String rawText = response.data['result'] ?? '';
      print("🎯 AI RESPONSE: $rawText"); 

      rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final Map<String, dynamic> data = jsonDecode(rawText);
      
      if (mounted) {
        _showResultDialog(data);
      }

    } catch (e) {
      print("🚨 EDGE FUNCTION ERROR: $e"); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'), 
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _showResultDialog(Map<String, dynamic> data) {
    String selectedMeal = 'lunch'; 
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1F22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Food Detected!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'] ?? 'Unknown Food', style: const TextStyle(color: Color(0xFFED6058), fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _macroRow('Calories', '${data['calories']} kcal', Colors.white),
                    _macroRow('Protein', '${data['protein']}g', const Color(0xFFED6058)),
                    _macroRow('Carbs', '${data['carbs']}g', const Color(0xFF4CAF50)),
                    _macroRow('Fats', '${data['fats']}g', const Color(0xFFFFC107)),
                    const SizedBox(height: 24),
                    const Text('Select Meal:', style: TextStyle(color: Colors.white54, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: const Color(0xFF2B2D31), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedMeal,
                          dropdownColor: const Color(0xFF2B2D31),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          items: const [
                            DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                            DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                            DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                            DropdownMenuItem(value: 'snack', child: Text('Snack')),
                          ],
                          onChanged: (val) {
                            if (val != null) setStateDialog(() => selectedMeal = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); 
                    setState(() => _imageBytes = null); 
                  }, 
                  child: const Text('DISCARD', style: TextStyle(color: Colors.white54))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED6058)),
                  onPressed: () {
                    context.read<AppState>().addFoodToMeal(
                      selectedMeal,
                      data['name'] ?? 'AI Food',
                      '1 Portion',
                      (data['calories'] as num?)?.toInt() ?? 0,
                      (data['protein'] as num?)?.toDouble() ?? 0.0,
                      (data['carbs'] as num?)?.toDouble() ?? 0.0,
                      (data['fats'] as num?)?.toDouble() ?? 0.0,
                    );
                    Navigator.pop(context); 
                    Navigator.pop(context); 
                  },
                  child: const Text('ADD MEAL', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _macroRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFED6058);

    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(
        children: [
          Positioned.fill(
            child: _imageBytes != null 
                ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                : Image.network('https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=800&auto=format&fit=crop', fit: BoxFit.cover),
          ),
          
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context)),
                  const Text('Scan Meal', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  // ΔΙΟΡΘΩΣΗ: Αφαιρέθηκε το νεκρό κουμπί του φακού και μπήκε κενό για συμμετρία
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          Center(
            child: _isScanning 
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: accentColor),
                    const SizedBox(height: 20),
                    const Text('AI is analyzing macros...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(border: Border.all(color: accentColor.withOpacity(0.8), width: 3), borderRadius: BorderRadius.circular(24)),
                    ),
                    const SizedBox(height: 24),
                    const Text('Position food within the frame to detect\nmacros.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 15, shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
                  ],
                ),
          ),

          if (!_isScanning) 
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _pickImage(ImageSource.gallery),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                          child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 26),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('UPLOAD', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accentColor, width: 4)),
                      child: Center(
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(color: accentColor, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 60), 
                ],
              ),
            )
        ],
      ),
    );
  }
}