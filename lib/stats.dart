import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF2B2D31);
    const cardColor = Color(0xFF1E1F22);
    const accentColor = Color(0xFFED6058);
    const proteinColor = Color(0xFFED6058); 
    const carbsColor = Color(0xFF4CAF50);   
    const fatsColor = Color(0xFFFFC107);    

    // ΤΡΑΒΑΜΕ ΤΑ ΔΕΔΟΜΕΝΑ ΑΠΟ ΤΟΝ ΕΓΚΕΦΑΛΟ
    final appState = context.watch<AppState>();
    final goal = appState.dailyGoal;
    final consumed = appState.consumedCalories;
    
    // Υπολογίζουμε το ποσοστό προόδου 
    double progress = goal > 0 ? consumed / goal : 0.0;
    if (progress > 1.0) progress = 1.0; 

    final goalProtein = ((goal * 0.30) / 4).round();
    final goalCarbs = ((goal * 0.40) / 4).round();
    final goalFats = ((goal * 0.30) / 9).round();

    final consumedProtein = appState.consumedProtein.round();
    final consumedCarbs = appState.consumedCarbs.round();
    final consumedFats = appState.consumedFats.round();

    // --- ΝΕΟ: ΥΠΟΛΟΓΙΣΜΟΣ 7 ΗΜΕΡΩΝ ΓΙΑ ΤΟ ΓΡΑΦΗΜΑ ---
    List<Map<String, dynamic>> weeklyData = [];
    int maxDailyKcal = goal > 0 ? goal : 2000; 

    for (int i = 6; i >= 0; i--) {
      DateTime day = DateTime.now().subtract(Duration(days: i));
      String dateStr = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      
      int dayCalories = 0;
      if (appState.mealHistory.containsKey(dateStr)) {
        var dayMeals = appState.mealHistory[dateStr]!;
        for (var mealType in dayMeals.keys) {
          for (var food in dayMeals[mealType]) {
            dayCalories += (food['calories'] as int? ?? 0);
          }
        }
      }
      if (dayCalories > maxDailyKcal) maxDailyKcal = dayCalories;
      
      List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      String dayName = weekdays[day.weekday - 1];
      if (i == 0) dayName = 'Today';
      
      weeklyData.add({
        'day': dayName,
        'calories': dayCalories,
      });
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        automaticallyImplyLeading: false, 
        title: const Text('Statistics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ΚΑΡΤΑ 1: ΣΥΝΟΛΙΚΗ ΠΡΟΟΔΟΣ ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))]
              ),
              child: Column(
                children: [
                  const Text('Daily Progress', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$consumed', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                          const Text('Consumed', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$goal', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                          const Text('Daily Goal', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            const Text('Macronutrients', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // --- ΚΑΡΤΑ 2: ΜΑΚΡΟΘΡΕΠΤΙΚΑ ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  _macroBar('Protein', consumedProtein, goalProtein, proteinColor),
                  const SizedBox(height: 24),
                  _macroBar('Carbs', consumedCarbs, goalCarbs, carbsColor),
                  const SizedBox(height: 24),
                  _macroBar('Fats', consumedFats, goalFats, fatsColor),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // --- ΚΑΡΤΑ 3: ΠΡΑΓΜΑΤΙΚΟ ΕΒΔΟΜΑΔΙΑΙΟ ΓΡΑΦΗΜΑ ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Weekly Analytics', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 150,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: weeklyData.map((data) {
                        double barHeight = (data['calories'] / maxDailyKcal) * 120;
                        bool isToday = data['day'] == 'Today';
                        
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 30,
                              height: barHeight > 0 ? barHeight : 5, 
                              decoration: BoxDecoration(
                                color: isToday ? accentColor : accentColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              data['day'], 
                              style: TextStyle(
                                color: isToday ? Colors.white : Colors.white54, 
                                fontSize: 12,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal
                              )
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80), 
          ],
        ),
      ),
    );
  }

  Widget _macroBar(String title, int consumed, int goal, Color color) {
    double progress = goal > 0 ? consumed / goal : 0.0;
    if (progress > 1.0) progress = 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${consumed}g / ${goal}g', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}