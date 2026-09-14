import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_state.dart';
import 'profile.dart'; 
import 'sign_in.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF2B2D31);
    const cardColor = Color(0xFF1E1F22);
    const accentColor = Color(0xFFED6058);

    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false, 
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: accentColor.withOpacity(0.2),
                      child: const Icon(Icons.person, size: 40, color: accentColor),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(Supabase.instance.client.auth.currentUser?.email ?? 'user@email.com', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                const Text('ACCOUNT', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                _buildSettingsCard(
                  cardColor,
                  children: [
                    _buildListTile(Icons.person_outline, 'Personal Data', () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                    }),
                    _buildDivider(),
                    SwitchListTile(
                      secondary: const Icon(Icons.square_foot, color: Colors.white70),
                      title: const Text('Metric Units (kg/cm)', style: TextStyle(color: Colors.white, fontSize: 16)),
                      value: appState.isMetric,
                      onChanged: (val) => appState.toggleUnits(val),
                      activeColor: accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                const Text('DATA & PRIVACY', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                _buildSettingsCard(
                  cardColor,
                  children: [
                    _buildListTile(Icons.download, 'Export Data (JSON)', () {
                      final data = appState.exportData();
                      Clipboard.setData(ClipboardData(text: data));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Data copied. Paste in notes to view/save.', style: TextStyle(color: Colors.white)), 
                          backgroundColor: Color(0xFF4CAF50),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }),
                    _buildDivider(),
                    _buildListTile(Icons.delete_sweep, 'Clear Local Cache', () async {
                      await appState.clearLocalCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('App cache cleared successfully!', style: TextStyle(color: Colors.white)), 
                            backgroundColor: Color(0xFF4CAF50),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }),
                  ],
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Text(
                  'Support: omniplate.info@gmail.com',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 16),
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
                      side: const BorderSide(color: accentColor, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('LOG OUT', style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(Color cardColor, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(color: Colors.white12, height: 1, indent: 56);
  }
}