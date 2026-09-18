import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'app_state.dart';                 
import 'scan_meal.dart';
import 'stats.dart';    
import 'settings.dart'; 
import 'search_food.dart'; 
import 'profile.dart'; 
import 'paywall_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),   
    const StatsScreen(),   
    const SettingsScreen() 
  ];

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF2B2D31);
    const cardColor = Color(0xFF1E1F22);
    const accentColor = Color(0xFFED6058);

    return Scaffold(
      backgroundColor: bgColor,
      body: _screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 0 
          ? FloatingActionButton.extended(
              onPressed: () {
                if (context.read<AppState>().isPro) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanMealScreen()));
                } else {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: const Color(0xFF1E1F22),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (context) => const PaywallScreen(),
                  );
                }
              },
              backgroundColor: accentColor,
              icon: const Icon(Icons.document_scanner_outlined, color: Colors.white),
              label: const Text('SCAN MEAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: cardColor,
        selectedItemColor: accentColor,
        unselectedItemColor: Colors.white54,
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    const bgColor = Color(0xFF2B2D31);
    const cardColor = Color(0xFF1E1F22);

    final weight = appState.weight;
    final dailyGoal = appState.dailyGoal;
    
    final targetProtein = (weight * 2.2).round();
    final targetFats = (weight * 1.0).round();
    final proteinKcal = targetProtein * 4;
    final fatsKcal = targetFats * 9;
    final remainingKcalForCarbs = dailyGoal - proteinKcal - fatsKcal;
    final targetCarbs = remainingKcalForCarbs > 0 ? (remainingKcalForCarbs / 4).round() : 0;

    final remProtein = (targetProtein - appState.consumedProtein).round();
    final remCarbs = (targetCarbs - appState.consumedCarbs).round();
    final remFats = (targetFats - appState.consumedFats).round();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        automaticallyImplyLeading: false, 
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white), 
              onPressed: () => appState.previousDay()
            ),
            const SizedBox(width: 8),
            Text(
              _formatDate(appState.currentDate), 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white54), 
              onPressed: () => appState.nextDay()
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white), 
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            }
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  Text('${appState.remainingCalories}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                  const Text('Kcal Remaining', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _macroIndicator('Protein', '${remProtein}g', const Color(0xFFED6058)), 
                      _macroIndicator('Carbs', '${remCarbs}g', const Color(0xFF4CAF50)), 
                      _macroIndicator('Fats', '${remFats}g', const Color(0xFFFFC107)), 
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Text('Meals', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            ...appState.dailyMeals.map((meal) {
              List foods = meal['foods'];
              bool isLogged = foods.isNotEmpty;
              
              int mealCalories = foods.fold(0, (sum, item) => sum + (item['calories'] as int));
              String subtitle = isLogged ? '${foods.length} items • $mealCalories kcal' : 'Not logged';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildMealCard(context, meal['id'], meal['name'], subtitle, meal['icon'], isLogged, foods),
              );
            }),
            const SizedBox(height: 80), 
          ],
        ),
      ),
    );
  }

  Widget _macroIndicator(String title, String value, Color color) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        Container(width: 50, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      ],
    );
  }

  Widget _buildMealCard(BuildContext context, String mealId, String title, String subtitle, IconData icon, bool isLogged, List foods) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F22),
        borderRadius: BorderRadius.circular(16),
        border: isLogged ? null : Border.all(color: Colors.white12, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: isLogged ? const Color(0xFFED6058).withOpacity(0.15) : Colors.transparent, shape: BoxShape.circle),
            child: Icon(icon, color: isLogged ? const Color(0xFFED6058) : Colors.white54, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(color: isLogged ? Colors.white70 : Colors.white38, fontSize: 14)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(isLogged ? Icons.check_circle : Icons.add_circle_outline),
            color: isLogged ? const Color(0xFF4CAF50) : Colors.white54,
            onPressed: () {
              if (!isLogged) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => SearchFoodScreen(mealId: mealId)));
              } else {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true, 
                  backgroundColor: const Color(0xFF1E1F22),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (context) {
                    return Consumer<AppState>(
                      builder: (context, appState, child) {
                        List updatedFoods = appState.mealHistory[appState.dateKey]?[mealId] ?? [];
                        
                        return SafeArea(
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewPadding.bottom + 20.0, 
                              top: 20.0, 
                              left: 16.0, 
                              right: 16.0
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                                const Text('Meal Items', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                
                                ...updatedFoods.asMap().entries.map((entry) {
                                  int index = entry.key;
                                  var food = entry.value;
                                  int qty = food['quantity'] ?? 1;

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(food['name'], style: const TextStyle(color: Colors.white)),
                                    subtitle: Text('${food['portion']} • ${food['calories']} kcal', style: const TextStyle(color: Colors.white54)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
                                          onPressed: () => appState.updateFoodQuantity(mealId, index, qty - 1),
                                        ),
                                        Text('$qty', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
                                          onPressed: () => appState.updateFoodQuantity(mealId, index, qty + 1),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Color(0xFFED6058)),
                                          onPressed: () {
                                            appState.removeFoodFromMeal(mealId, index);
                                            if (updatedFoods.length == 1) Navigator.pop(context); 
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const Divider(color: Colors.white12, height: 30),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.add, color: Color(0xFF4CAF50)),
                                  title: const Text('Add more food', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 16, fontWeight: FontWeight.bold)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => SearchFoodScreen(mealId: mealId)));
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    );
                  }
                );
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) return 'Today';
    if (targetDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (targetDate == today.add(const Duration(days: 1))) return 'Tomorrow';
    
    List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }
}