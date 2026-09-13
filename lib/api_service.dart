import 'dart:convert';
import 'package:http/http.dart' as http;
import 'food_model.dart';

class ApiService {
  static const String _baseUrl = 'https://world.openfoodfacts.org/cgi/search.pl';

  static Future<List<FoodItem>> searchFoods(String query) async {
    if (query.trim().isEmpty) return [];

    // ΝΕΟ: Ελέγχουμε αν το query είναι μόνο αριθμοί (άρα είναι Barcode!)
    final isBarcode = RegExp(r'^[0-9]+$').hasMatch(query.trim());
    
    // Αν είναι barcode, χτυπάμε το ειδικό γρήγορο API. Αλλιώς, την κανονική αναζήτηση.
    final url = isBarcode 
        ? Uri.parse('https://world.openfoodfacts.org/api/v0/product/${query.trim()}.json')
        : Uri.parse('$_baseUrl?search_terms=$query&search_simple=1&action=process&json=1&page_size=30');
    
    int maxRetries = 5; 
    int currentTry = 0;
    int delayMs = 1000; 

    while (currentTry < maxRetries) {
      try {
        final response = await http.get(
          url,
          headers: {
            'User-Agent': 'OmniPlate_MVP - FlutterWeb - Version 1.0 - test@gmail.com',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          if (isBarcode) {
            // Το Barcode API επιστρέφει ένα συγκεκριμένο 'product'
            if (data['status'] == 1 && data['product'] != null) {
              final food = FoodItem.fromJson(data['product']);
              // Το MAGIC FILTER μας: Κόβουμε τα άκυρα δεδομένα
              if (food.name.isNotEmpty && food.name != 'Unknown Food' && food.calories > 0) {
                return [food];
              }
            }
            return []; // Αν δεν το βρει ή έχει μηδέν θερμίδες, γυρνάει άδειο
          } else {
            // Η κανονική αναζήτηση επιστρέφει λίστα 'products'
            final List products = data['products'] ?? [];
            return products
                .map((json) => FoodItem.fromJson(json))
                .where((food) => 
                    food.name.isNotEmpty && 
                    food.name != 'Unknown Food' &&
                    food.calories > 0 
                )
                .toList();
          }
          
        } else if (response.statusCode == 503) {
          currentTry++;
          print('Server Error 503: Attempt $currentTry of $maxRetries. Retrying in ${delayMs}ms...');
          
          await Future.delayed(Duration(milliseconds: delayMs)); 
          delayMs *= 2; 
          
        } else {
          return [];
        }
      } catch (e) {
        return [];
      }
    }
    
    print('Failed after 5 attempts.');
    return []; 
  }
}