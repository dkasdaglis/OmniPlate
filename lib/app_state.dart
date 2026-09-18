import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'dart:convert'; 
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppState extends ChangeNotifier {
  int age = 21;
  double weight = 78.0;
  double height = 182.0;
  String activityLevel = 'Moderate';
  String gender = 'Male'; 
  String goal = 'Lose Weight'; 
  bool isMetric = true;

  bool _isPro = false;
  bool get isPro => _isPro;

  void updateProStatus(bool status) {
    _isPro = status;
    notifyListeners();
  }

  Future<void> initRevenueCat() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      PurchasesConfiguration configuration = PurchasesConfiguration(dotenv.env['REVENUECAT_KEY']!);
      await Purchases.configure(configuration);

      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _checkEntitlement(customerInfo);
      });

      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      _checkEntitlement(customerInfo);
    } catch (e) {
      debugPrint("RevenueCat Init Error: $e");
    }
  }

  void _checkEntitlement(CustomerInfo customerInfo) {
    final isOmniProActive = customerInfo.entitlements.all["omnipro"]?.isActive ?? false;
    final isProActive = customerInfo.entitlements.all["pro"]?.isActive ?? false;

    _isPro = isOmniProActive || isProActive;
    notifyListeners();
  }

  int dailyGoal = 1850;
  DateTime currentDate = DateTime.now();
  Map<String, Map<String, dynamic>> mealHistory = {};

  AppState() {
    _loadData();
  }

  String get dateKey {
    return "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    age = prefs.getInt('age') ?? 21;
    weight = prefs.getDouble('weight') ?? 78.0;
    height = prefs.getDouble('height') ?? 182.0;
    activityLevel = prefs.getString('activityLevel') ?? 'Moderate';
    gender = prefs.getString('gender') ?? 'Male';
    goal = prefs.getString('goal') ?? 'Lose Weight'; 
    isMetric = prefs.getBool('isMetric') ?? true;

    String? historyJson = prefs.getString('mealHistory');
    if (historyJson != null) {
      Map<String, dynamic> decoded = json.decode(historyJson);
      mealHistory = {};
      decoded.forEach((date, meals) {
        mealHistory[date] = Map<String, dynamic>.from(meals);
      });
    }
    calculateMacros(); 
    notifyListeners(); 
  }

  Future<void> toggleUnits(bool value) async {
    isMetric = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isMetric', isMetric);
  }

  Future<void> clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mealHistory');
    mealHistory.clear();
    notifyListeners();
  }

  String exportData() {
    return json.encode(mealHistory);
  }

  Future<void> syncWithSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profileRes = await Supabase.instance.client.from('users').select().eq('id', user.id).maybeSingle();
      if (profileRes != null) {
        age = profileRes['age'] ?? age;
        weight = (profileRes['weight'] ?? weight).toDouble();
        height = (profileRes['height'] ?? height).toDouble();
        activityLevel = profileRes['activity_level'] ?? activityLevel;
        gender = profileRes['gender'] ?? gender;
        goal = profileRes['goal'] ?? goal;
        dailyGoal = profileRes['daily_goal_calories'] ?? dailyGoal;
      }

      final mealsRes = await Supabase.instance.client.from('meals').select().eq('user_id', user.id);
      mealHistory.clear(); 
      for (var m in mealsRes) {
        String date = m['date_logged'];
        String type = m['meal_type'];
        if (!mealHistory.containsKey(date)) mealHistory[date] = {'breakfast': [], 'lunch': [], 'dinner': [], 'snack': []};
        if (!mealHistory[date]!.containsKey(type)) mealHistory[date]![type] = [];

        mealHistory[date]![type].add({
          'db_id': m['id'],
          'name': m['food_name'],
          'portion': m['portion'],
          'calories': m['calories'],
          'protein': (m['protein'] ?? 0).toDouble(),
          'carbs': (m['carbs'] ?? 0).toDouble(),
          'fats': (m['fats'] ?? 0).toDouble(),
        });
      }
      
      _saveHistory();
      calculateMacros();
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing data: $e');
    }
  }

  void nextDay() {
    currentDate = currentDate.add(const Duration(days: 1));
    notifyListeners();
  }

  void previousDay() {
    currentDate = currentDate.subtract(const Duration(days: 1));
    notifyListeners();
  }

  List<Map<String, dynamic>> get dailyMeals {
    List<Map<String, dynamic>> meals = [
      {'id': 'breakfast', 'name': 'Breakfast', 'icon': Icons.breakfast_dining, 'foods': []},
      {'id': 'lunch', 'name': 'Lunch', 'icon': Icons.lunch_dining, 'foods': []},
      {'id': 'dinner', 'name': 'Dinner', 'icon': Icons.dinner_dining, 'foods': []},
      {'id': 'snack', 'name': 'Snack', 'icon': Icons.apple, 'foods': []},
    ];

    if (mealHistory.containsKey(dateKey)) {
      var savedMeals = mealHistory[dateKey]!;
      for (var meal in meals) {
        String mId = meal['id'];
        if (savedMeals.containsKey(mId)) {
          meal['foods'] = List<Map<String, dynamic>>.from(savedMeals[mId]);
        }
      }
    }
    return meals;
  }

  int get consumedCalories {
    int total = 0;
    for (var meal in dailyMeals) { 
      List foods = meal['foods'];
      for (var food in foods) {
        total += (food['calories'] as int);
      }
    }
    return total;
  }

  int get remainingCalories => dailyGoal - consumedCalories;

  double get consumedProtein {
    double total = 0;
    for (var meal in dailyMeals) {
      for (var food in meal['foods']) { total += (food['protein'] ?? 0.0); }
    }
    return total;
  }

  double get consumedCarbs {
    double total = 0;
    for (var meal in dailyMeals) {
      for (var food in meal['foods']) { total += (food['carbs'] ?? 0.0); }
    }
    return total;
  }

  double get consumedFats {
    double total = 0;
    for (var meal in dailyMeals) {
      for (var food in meal['foods']) { total += (food['fats'] ?? 0.0); }
    }
    return total;
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mealHistory', json.encode(mealHistory));
  }

  Future<void> addFoodToMeal(String mealId, String foodName, String portion, int calories, double protein, double carbs, double fats) async {
    if (!mealHistory.containsKey(dateKey)) {
      mealHistory[dateKey] = {'breakfast': [], 'lunch': [], 'dinner': [], 'snack': []};
    }
    if (!mealHistory[dateKey]!.containsKey(mealId)) {
      mealHistory[dateKey]![mealId] = [];
    }

    final newFood = {
      'db_id': null, 
      'name': foodName,
      'portion': portion,
      'calories': calories,
      'protein': protein, 
      'carbs': carbs,     
      'fats': fats,       
      'quantity': 1, 
    };
    
    mealHistory[dateKey]![mealId].add(newFood);
    _saveHistory(); 
    notifyListeners(); 

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final response = await Supabase.instance.client.from('meals').insert({
          'user_id': user.id,
          'date_logged': dateKey,
          'meal_type': mealId,
          'food_name': foodName,
          'portion': portion,
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fats': fats,
        }).select();

        final dbId = response[0]['id'];
        mealHistory[dateKey]![mealId].last['db_id'] = dbId;
        _saveHistory(); 
      } catch (e) {
        debugPrint('Saved offline. Will sync later. Error: $e');
      }
    }
  }

  Future<void> removeFoodFromMeal(String mealId, int foodIndex) async {
    if (mealHistory.containsKey(dateKey) && mealHistory[dateKey]!.containsKey(mealId)) {
      final foodList = mealHistory[dateKey]![mealId];
      if (foodIndex < 0 || foodIndex >= foodList.length) return;

      final foodItem = foodList[foodIndex];
      final dbId = foodItem['db_id']; 

      foodList.removeAt(foodIndex);
      _saveHistory();
      notifyListeners(); 

      if (dbId != null) {
        try {
          await Supabase.instance.client.from('meals').delete().eq('id', dbId);
        } catch (e) {
          debugPrint('Deleted offline. Cloud error: $e');
        }
      }
    }
  }

  Future<void> updateFoodQuantity(String mealId, int foodIndex, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeFoodFromMeal(mealId, foodIndex);
      return;
    }

    if (mealHistory.containsKey(dateKey) && mealHistory[dateKey]!.containsKey(mealId)) {
      final foodList = mealHistory[dateKey]![mealId];
      if (foodIndex < 0 || foodIndex >= foodList.length) return;

      final foodItem = foodList[foodIndex];

      foodItem['base_calories'] ??= foodItem['calories'];
      foodItem['base_protein'] ??= foodItem['protein'];
      foodItem['base_carbs'] ??= foodItem['carbs'];
      foodItem['base_fats'] ??= foodItem['fats'];

      foodItem['quantity'] = newQuantity;
      foodItem['calories'] = (foodItem['base_calories'] as int) * newQuantity;
      foodItem['protein'] = (foodItem['base_protein'] as double) * newQuantity;
      foodItem['carbs'] = (foodItem['base_carbs'] as double) * newQuantity;
      foodItem['fats'] = (foodItem['base_fats'] as double) * newQuantity;

      _saveHistory();
      notifyListeners(); 

      final dbId = foodItem['db_id'];
      if (dbId != null) {
        try {
          await Supabase.instance.client.from('meals').update({
            'calories': foodItem['calories'],
            'protein': foodItem['protein'],
            'carbs': foodItem['carbs'],
            'fats': foodItem['fats'],
          }).eq('id', dbId);
        } catch (e) {
          debugPrint('Update offline. Cloud error: $e');
        }
      }
    }
  }

  Future<void> updateUserData({
    required int newAge, 
    required double newWeight, 
    required double newHeight, 
    required String newActivity,
    String? newGoal,
    String? newGender,
  }) async {
    age = newAge;
    weight = newWeight;
    height = newHeight;
    activityLevel = newActivity;
    if (newGoal != null) goal = newGoal;
    if (newGender != null) gender = newGender;

    calculateMacros();
    notifyListeners(); 

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('age', age);
    await prefs.setDouble('weight', weight);
    await prefs.setDouble('height', height);
    await prefs.setString('activityLevel', activityLevel);
    await prefs.setString('gender', gender);
    await prefs.setString('goal', goal);

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('users').upsert({
          'id': user.id, 
          'age': age,
          'weight': weight,
          'height': height,
          'activity_level': activityLevel,
          'gender': gender,
          'goal': goal,
          'daily_goal_calories': dailyGoal,
        });
      } catch (e) {
        debugPrint('Error saving to Supabase: $e');
      }
    }
  }

  void calculateMacros() {
    double bmr = (10 * weight) + (6.25 * height) - (5 * age);
    if (gender == 'Male') {
      bmr += 5;
    } else {
      bmr -= 161;
    }

    double multiplier = 1.2;
    if (activityLevel == 'Light') multiplier = 1.375;
    else if (activityLevel == 'Moderate') multiplier = 1.55;
    else if (activityLevel == 'Active') multiplier = 1.725;
    else if (activityLevel == 'Very Active') multiplier = 1.9;

    double tdee = bmr * multiplier;
    int finalGoal = tdee.round();
    if (goal == 'Lose Weight') finalGoal -= 500;
    else if (goal == 'Gain Muscle') finalGoal += 300;

    dailyGoal = finalGoal;
  }
}