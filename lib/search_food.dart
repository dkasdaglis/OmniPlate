import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart'; // ΝΕΟ IMPORT: Το πακέτο του Barcode!
import 'app_state.dart';
import 'api_service.dart'; 
import 'food_model.dart';  

class SearchFoodScreen extends StatefulWidget {
  final String mealId;

  const SearchFoodScreen({super.key, required this.mealId});

  @override
  State<SearchFoodScreen> createState() => _SearchFoodScreenState();
}

class _SearchFoodScreenState extends State<SearchFoodScreen> {
  final TextEditingController _controller = TextEditingController();
  String _searchQuery = '';
  List<FoodItem> _searchResults = [];
  bool _isLoading = false;

  void _performSearch(String query) async {
    if (query.trim().length < 3) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _searchQuery = query;
    });

    final results = await ApiService.searchFoods(query);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _searchResults = results;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF2B2D31);
    const cardColor = Color(0xFF1E1F22);
    const accentColor = Color(0xFFED6058);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Food', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              onSubmitted: _performSearch, 
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search foods or scan...',
                hintStyle: const TextStyle(color: Colors.white54),
                // ΝΕΟ: Το εικονίδιο της κάμερας!
                prefixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: accentColor),
                  onPressed: () async {
                    // 1. Ανοίγει η οθόνη του Scanner
                    var res = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SimpleBarcodeScannerPage(),
                      ),
                    );
                    // 2. Αν βρήκε barcode και δεν πατήσαμε ακύρωση (-1)
                    if (res is String && res != '-1' && res.isNotEmpty) {
                      _controller.text = res; // Βάζει το νούμερο στο πεδίο
                      _performSearch(res);    // Ρωτάει αυτόματα τον server!
                    }
                  },
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: accentColor),
                  onPressed: () => _performSearch(_controller.text),
                ),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showCustomMealDialog(context),
                icon: const Icon(Icons.add_box, color: accentColor),
                label: const Text('Add Custom Meal', style: TextStyle(color: accentColor, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: accentColor)) 
                : _searchResults.isEmpty && _searchQuery.isNotEmpty
                  ? const Center(child: Text('No foods found.', style: TextStyle(color: Colors.white54, fontSize: 16)))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final food = _searchResults[index];
                        return _foodItem(context, food, cardColor, accentColor);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _foodItem(BuildContext context, FoodItem food, Color cardColor, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name, 
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis 
                ),
                const SizedBox(height: 4),
                Text('100g • ${food.calories} kcal • P: ${food.protein.round()}g C: ${food.carbs.round()}g F: ${food.fats.round()}g', 
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_circle, color: accentColor, size: 28),
            onPressed: () => _showGramDialog(context, food), 
          ),
        ],
      ),
    );
  }

  void _showGramDialog(BuildContext context, FoodItem food) {
    TextEditingController gramController = TextEditingController(text: '100');
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1F22),
          title: Text('Add ${food.name}', style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
          content: TextField(
            controller: gramController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Amount (grams)', labelStyle: TextStyle(color: Colors.white54)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED6058)),
              onPressed: () {
                double grams = double.tryParse(gramController.text) ?? 100.0;
                double multiplier = grams / 100.0;
                
                int finalCalories = (food.calories * multiplier).round();
                double finalProtein = food.protein * multiplier;
                double finalCarbs = food.carbs * multiplier;
                double finalFats = food.fats * multiplier;

                context.read<AppState>().addFoodToMeal(
                  widget.mealId, 
                  food.name, 
                  '${grams.round()}g', 
                  finalCalories,
                  finalProtein,
                  finalCarbs,
                  finalFats,
                );
                
                Navigator.pop(context); 
                Navigator.pop(context); 
              },
              child: const Text('ADD', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );
  }

  void _showCustomMealDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final pCtrl = TextEditingController();
    final cCtrl = TextEditingController();
    final fCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1F22),
          title: const Text('Add Custom Meal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Meal Name', labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: calCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Total Calories', labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: pCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Total Protein (g)', labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: cCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Total Carbs (g)', labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: fCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Total Fats (g)', labelStyle: TextStyle(color: Colors.white54))),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED6058)),
              onPressed: () {
                context.read<AppState>().addFoodToMeal(
                  widget.mealId, 
                  nameCtrl.text.isEmpty ? 'Custom Meal' : nameCtrl.text, 
                  'Custom', 
                  int.tryParse(calCtrl.text) ?? 0,
                  double.tryParse(pCtrl.text) ?? 0.0,
                  double.tryParse(cCtrl.text) ?? 0.0,
                  double.tryParse(fCtrl.text) ?? 0.0,
                );
                Navigator.pop(context); 
                Navigator.pop(context); 
              },
              child: const Text('ADD', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );
  }
}