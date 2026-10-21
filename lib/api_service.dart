import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'food_model.dart';

class ApiService {
  // 1. ΑΝΑΖΗΤΗΣΗ ΜΕ ΚΕΙΜΕΝΟ (Μπάρα αναζήτησης / Βελάκι) -> USDA API
  static Future<List<FoodItem>> searchFoods(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // Αν ο χρήστης πληκτρολόγησε με το χέρι καθαρό barcode (8 έως 14 ψηφία), στείλ' το στο OpenFoodFacts
    if (RegExp(r'^\d{8,14}$').hasMatch(cleanQuery)) {
      return searchByBarcode(cleanQuery);
    }

    // Παίρνουμε το κλειδί από το .env (ή χρησιμοποιούμε το δωρεάν DEMO_KEY αν δεν υπάρχει)
    final apiKey = dotenv.env['USDA_API_KEY']?.trim().isNotEmpty == true
        ? dotenv.env['USDA_API_KEY']!.trim()
        : 'DEMO_KEY';

    try {
      // Χρησιμοποιούμε Foundation & SR Legacy για να φέρνει ΚΑΘΑΡΑ τρόφιμα (πατάτα, ρύζι, κοτόπουλο κλπ.) ανά 100g
      final url = Uri.parse(
        'https://api.nal.usda.gov/fdc/v1/foods/search?api_key=$apiKey&query=${Uri.encodeComponent(cleanQuery)}&dataType=Foundation,SR%20Legacy&pageSize=25',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List foods = data['foods'] ?? [];

        List<FoodItem> results = foods
            .map((jsonItem) => _parseUsdaFood(jsonItem))
            .where((food) => food.name != 'Unknown Food' && food.calories > 0)
            .toList();

        // Αν βρήκαμε αποτελέσματα στο USDA, τα επιστρέφουμε αμέσως!
        if (results.isNotEmpty) {
          return results;
        }
      }
    } catch (e) {
      debugPrint('USDA API Error: $e');
    }

    // FALLBACK: Αν κάποιος έγραψε στα Ελληνικά (π.χ. "πατάτα") και το USDA επέστρεψε 0 αποτελέσματα,
    // ψάχνουμε αυτόματα στο OpenFoodFacts για να μη μείνει άδεια η οθόνη!
    return _searchOpenFoodFactsText(cleanQuery);
  }

  // Μετατροπή των δεδομένων του USDA (που είναι πάντα ανά 100g) σε FoodItem
  static FoodItem _parseUsdaFood(Map<String, dynamic> json) {
    String name = json['description']?.toString() ?? 'Unknown Food';

    double calories = 0.0;
    double protein = 0.0;
    double carbs = 0.0;
    double fats = 0.0;

    final List nutrients = json['foodNutrients'] ?? [];
    for (var n in nutrients) {
      final int? id = n['nutrientId'];
      final String numStr = n['nutrientNumber']?.toString() ?? '';
      final double val = (n['value'] as num?)?.toDouble() ?? 0.0;

      // Θερμίδες (Energy kcal)
      if (id == 1008 || id == 2047 || numStr == '208') {
        if (calories == 0.0) calories = val;
      } 
      // Πρωτεΐνη
      else if (id == 1003 || numStr == '203') {
        protein = val;
      } 
      // Υδατάνθρακες
      else if (id == 1005 || numStr == '205') {
        carbs = val;
      } 
      // Λιπαρά
      else if (id == 1004 || numStr == '204') {
        fats = val;
      }
    }

    // Αν κάποιο Foundation food έχει μόνο τους μακροθρεπτικούς χωρίς το πεδίο Energy, το υπολογίζουμε:
    if (calories == 0.0 && (protein > 0 || carbs > 0 || fats > 0)) {
      calories = (protein * 4) + (carbs * 4) + (fats * 9);
    }

    final String foodId = json['fdcId']?.toString() ?? 'usda_${DateTime.now().millisecondsSinceEpoch}';

    return FoodItem(
      id: foodId,
      name: name,
      calories: calories.round(),
      protein: protein,
      carbs: carbs,
      fats: fats,
    );
  }

  // 2. ΑΝΑΖΗΤΗΣΗ ΜΕ BARCODE (Κάμερα Scanner) -> OPENFOODFACTS API (Συσκευασμένα)
  static Future<List<FoodItem>> searchByBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return [];

    try {
      final barcodeUrl = Uri.parse(
        'https://world.openfoodfacts.org/api/v0/product/$cleanBarcode.json',
      );
      final response = await http.get(
        barcodeUrl,
        headers: {'User-Agent': 'OmniPlate - Android - Version 1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final food = FoodItem.fromJson(data['product']);
          if (food.name != 'Unknown Food') {
            return [food];
          }
        }
      }
    } catch (e) {
      debugPrint('OpenFoodFacts Barcode Error: $e');
    }
    return [];
  }

  // Βοηθητική μέθοδος OpenFoodFacts αν ο χρήστης γράψει ελληνικές λέξεις στην αναζήτηση
  static Future<List<FoodItem>> _searchOpenFoodFactsText(String query) async {
    try {
      final url = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(query)}&search_simple=1&action=process&json=1&page_size=20',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'OmniPlate - Android - Version 1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List products = data['products'] ?? [];

        return products
            .map((json) => FoodItem.fromJson(json))
            .where((food) => food.name != 'Unknown Food' && food.calories > 0)
            .toList();
      }
    } catch (e) {
      debugPrint('OpenFoodFacts Text Fallback Error: $e');
    }
    return [];
  }
}