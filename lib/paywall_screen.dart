import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'app_state.dart';
import 'scan_meal.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Package? _monthlyPackage;
  Package? _yearlyPackage;
  
  // ΝΕΟ: Αυτή η μεταβλητή ελέγχει 100% το UI, άσχετα με το RevenueCat!
  String _selectedPlan = 'annual'; 

  bool _isLoadingOfferings = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        for (var package in offerings.current!.availablePackages) {
          if (package.packageType == PackageType.annual || package.identifier.toLowerCase().contains('year') || package.identifier.toLowerCase().contains('annual')) {
            _yearlyPackage = package;
          } else if (package.packageType == PackageType.monthly || package.identifier.toLowerCase().contains('month')) {
            _monthlyPackage = package;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching offerings: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOfferings = false;
        });
      }
    }
  }

  Future<void> _purchaseSelected() async {
    // Βρίσκουμε ποιο πακέτο αντιστοιχεί στην επιλογή του UI
    Package? packageToBuy = _selectedPlan == 'annual' ? _yearlyPackage : _monthlyPackage;

    if (packageToBuy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan not fully loaded yet. Please wait a second.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _isPurchasing = true;
    });

    try {
      final dynamic res = await (Purchases as dynamic).purchasePackage(packageToBuy);
      final CustomerInfo customerInfo = (res is CustomerInfo) ? res : res.customerInfo;

      final bool isPro = customerInfo.entitlements.all["omnipro"]?.isActive ?? 
                         customerInfo.entitlements.all["pro"]?.isActive ?? 
                         customerInfo.entitlements.active.isNotEmpty;

      if (isPro && mounted) {
        context.read<AppState>().updateProStatus(true);
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SuccessProScreen()));
      }
    } on PlatformException catch (e) {
      if (e.code != '1' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: ${e.message ?? e.code}'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      final CustomerInfo customerInfo = await Purchases.restorePurchases();
      final bool isPro = customerInfo.entitlements.all["omnipro"]?.isActive ?? 
                         customerInfo.entitlements.all["pro"]?.isActive ?? 
                         customerInfo.entitlements.active.isNotEmpty;

      if (mounted) {
        if (isPro) {
          context.read<AppState>().updateProStatus(true);
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (context) => const SuccessProScreen()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active subscriptions found.'), backgroundColor: Colors.white38),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF1E1F22);
    const accentColor = Color(0xFFED6058);

    final yearlyPrice = _yearlyPackage?.storeProduct.priceString ?? '€45.00';
    final monthlyPrice = _monthlyPackage?.storeProduct.priceString ?? '€5.00';

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Color(0xFF141517),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: _isLoadingOfferings
            ? const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator(color: accentColor)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  const Icon(Icons.workspace_premium, color: accentColor, size: 52),
                  const SizedBox(height: 16),
                  
                  const Text(
                    'Unlock OmniPro',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  const Text(
                    'Get unlimited AI food scanning and advanced macro tracking.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 28),

                  // --- ANNUAL PLAN ---
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPlan = 'annual'; // Αλλάζει αμέσως χωρίς if!
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedPlan == 'annual' ? accentColor : Colors.white12,
                          width: _selectedPlan == 'annual' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Annual Pass', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0x33ED6058),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('BEST VALUE', style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text('Billed annually', style: TextStyle(color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                          Text(
                            yearlyPrice,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- MONTHLY PLAN ---
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPlan = 'monthly'; // Αλλάζει αμέσως χωρίς if!
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedPlan == 'monthly' ? accentColor : Colors.white12,
                          width: _selectedPlan == 'monthly' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monthly Pass', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('Cancel anytime', style: TextStyle(color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                          Text(
                            monthlyPrice,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isPurchasing ? null : _purchaseSelected,
                      child: _isPurchasing
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _selectedPlan == 'annual' ? 'Subscribe ($yearlyPrice / year)' : 'Subscribe ($monthlyPrice / month)',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: _isPurchasing ? null : _restorePurchases,
                    child: const Text('Restore Purchases', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ),
                ],
              ),
      ),
    );
  }
}

// Η οθόνη επιτυχίας παραμένει ίδια, ακριβώς κάτω από το PaywallScreen
class SuccessProScreen extends StatefulWidget {
  const SuccessProScreen({super.key});

  @override
  State<SuccessProScreen> createState() => _SuccessProScreenState();
}

class _SuccessProScreenState extends State<SuccessProScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ScanMealScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B2D31),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFED6058).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium, color: Color(0xFFED6058), size: 80),
            ),
            const SizedBox(height: 32),
            const Text('Welcome to OmniPro!', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Your purchase was successful.\nAI Meal Scanning is now unlocked.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Color(0xFFED6058)),
          ],
        ),
      ),
    );
  }
}