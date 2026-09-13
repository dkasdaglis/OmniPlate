class FoodItem {
  final String id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fats;
  final String brand;

  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.brand = '',
  });

  // Εδώ γίνεται η μαγεία: Μεταφράζουμε τα ακαταλαβίστικα δεδομένα του ίντερνετ (JSON) σε αντικείμενο Dart
  factory FoodItem.fromJson(Map<String, dynamic> json) {
    // Το Open Food Facts κρύβει τα macros μέσα σε ένα υπο-αντικείμενο που λέγεται "nutriments"
    final nutriments = json['nutriments'] ?? {};
    
    return FoodItem(
      id: json['id'] ?? json['code'] ?? '',
      name: json['product_name'] ?? 'Unknown Food',
      brand: json['brands'] ?? '',
      
      // Διαβάζουμε τα δεδομένα ανά 100 γραμμάρια και προσέχουμε μην σκάσει αν λείπει κάτι (βάζουμε 0)
      calories: (nutriments['energy-kcal_100g'] ?? 0).toInt(),
      protein: (nutriments['proteins_100g'] ?? 0.0).toDouble(),
      carbs: (nutriments['carbohydrates_100g'] ?? 0.0).toDouble(),
      fats: (nutriments['fat_100g'] ?? 0.0).toDouble(),
    );
  }
}