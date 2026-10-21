import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'food_model.dart';

class ApiService {
  // 1. ΑΝΑΖΗΤΗΣΗ ΜΕ ΚΕΙΜΕΝΟ (Μπάρα αναζήτησης / Βελάκι) -> USDA API με Smart Ranking
  static Future<List<FoodItem>> searchFoods(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // Αν ο χρήστης πληκτρολόγησε καθαρό barcode (8 έως 14 ψηφία), στείλ' το στο OpenFoodFacts
    if (RegExp(r'^\d{8,14}$').hasMatch(cleanQuery)) {
      return searchByBarcode(cleanQuery);
    }

    final apiKey = dotenv.env['USDA_API_KEY']?.trim().isNotEmpty == true
        ? dotenv.env['USDA_API_KEY']!.trim()
        : 'DEMO_KEY';

    try {
      // Χρησιμοποιούμε Uri.https για σωστό encoding του dataType (ώστε να μη φέρνει ποτέ Branded προϊόντα)
      final url = Uri.https(
        'api.nal.usda.gov',
        '/fdc/v1/foods/search',
        {
          'api_key': apiKey,
          'query': cleanQuery,
          'dataType': ['Foundation', 'SR Legacy'],
          'pageSize': '50',
        },
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List foods = data['foods'] ?? [];

        List<FoodItem> results = foods
            .map((jsonItem) => _parseUsdaFood(jsonItem))
            .where((food) => food.name != 'Unknown Food' && food.calories > 0)
            .toList();

        if (results.isNotEmpty) {
          // Εφαρμόζουμε την έξυπνη ταξινόμηση για να βγαίνουν πρώτα τα απλά/βασικά τρόφιμα
          results.sort((a, b) => _scoreFood(b.name, cleanQuery).compareTo(_scoreFood(a.name, cleanQuery)));

          // Αφαιρούμε τυχόν διπλότυπα ονόματα (π.χ. δύο ίδια "Carrots, baby, raw")
          final seenNames = <String>{};
          final uniqueResults = <FoodItem>[];
          for (var item in results) {
            final key = '${item.name.toLowerCase()}_${item.calories}';
            if (!seenNames.contains(key)) {
              seenNames.add(key);
              uniqueResults.add(item);
            }
          }

          return uniqueResults.take(25).toList();
        }
      }
    } catch (e) {
      debugPrint('USDA API Error: $e');
    }

    // FALLBACK: Αν κάποιος έγραψε στα Ελληνικά, ψάχνουμε στο OpenFoodFacts
    return _searchOpenFoodFactsText(cleanQuery);
  }

  // ΕΞΥΠΝΗ ΒΑΘΜΟΛΟΓΗΣΗ ΤΡΟΦΙΜΩΝ (Smart Dietitian Sorter)
  static int _scoreFood(String foodName, String query) {
    final name = foodName.toLowerCase();
    final q = query.toLowerCase().trim();
    
    // Βρίσκουμε την κύρια λέξη (αν έγραψε π.χ. "tomato raw", η πρώτη λέξη είναι "tomato")
    final firstWord = q.split(' ').first;
    // Φτιάχνουμε και τον ενικό/πληθυντικό (π.χ. tomato <-> tomatoes, carrot <-> carrots)
    final baseWord = firstWord.endsWith('es')
        ? firstWord.substring(0, firstWord.length - 2)
        : (firstWord.endsWith('s') ? firstWord.substring(0, firstWord.length - 1) : firstWord);

    int score = 0;

    // 1. Μεγάλο Bonus αν το τρόφιμο ΞΕΚΙΝΑΕΙ με τη λέξη που ψάχνουμε (π.χ. "Tomatoes, ..." αντί για "Bread, potato")
    if (name == q || name == baseWord || name == '${baseWord}s' || name == '${baseWord}es') {
      score += 150;
    } else if (name.startsWith('$baseWord,') || name.startsWith('${baseWord}s,') || name.startsWith('${baseWord}es,')) {
      score += 100;
    } else if (name.startsWith(baseWord)) {
      score += 70;
    } else if (name.contains(baseWord)) {
      score += 20;
    }

    // 2. Bonus αν είναι ωμή (raw) ή απλά μαγειρεμένη τροφή
    if (name.contains(', raw') || name.endsWith(' raw')) {
      score += 50;
    }
    if (name.contains('cooked') || name.contains('boiled') || name.contains('roasted') || name.contains('grilled') || name.contains('baked') || name.contains('steamed')) {
      score += 35;
    }
    if (name.contains('breast') || name.contains('whole') || name.contains('fresh') || name.contains('ripe')) {
      score += 25;
    }

    // 3. Ποινή (Penalty) για επεξεργασμένα/παράγωγα τρόφιμα (εκτός αν ο χρήστης τα ζήτησε ρητά!)
    final penaltyWords = [
      'powder', 'dehydrated', 'dried', 'flour', 'spread', 'babyfood', 
      'meatless', 'imitation', 'fat,', 'skin', 'giblets', 'frankfurter', 
      'bologna', 'sausage', 'nuggets', 'tenders', 'bread', 'pancakes', 
      'chips', 'salad', 'soup', 'sauce', 'puree', 'paste', 'juice', 
      'beverage', 'soda', 'canned', 'frozen', 'leaves', 'peel', 'syrup', 
      'oil', 'dressing', 'pudding', 'pie', 'cake', 'cookie', 'crackers'
    ];

    for (var word in penaltyWords) {
      if (name.contains(word) && !q.contains(word)) {
        score -= 80;
      }
    }

    // 4. Μικρή προτίμηση σε πιο λιτές και καθαρές περιγραφές
    score -= (name.length ~/ 15);

    return score;
  }

  // Μετατροπή των δεδομένων του USDA (πάντα ανά 100g) σε FoodItem
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

  // 2. ΑΝΑΖΗΤΗΣΗ ΜΕ BARCODE (Κάμερα Scanner) -> OPENFOODFACTS API
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

  // Βοηθητική μέθοδος OpenFoodFacts αν ο χρήστης γράψει ελληνικά στην αναζήτηση
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