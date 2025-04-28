import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/localization/app_localizations.dart';

class PlasmaPurchasePage extends StatefulWidget {
  final String userId;

  const PlasmaPurchasePage({super.key, required this.userId});
  
  @override
  State<PlasmaPurchasePage> createState() => _PlasmaPurchasePageState();
}

class _PlasmaPurchasePageState extends State<PlasmaPurchasePage> {
  int _currentCoins = 0;
  int _currentPlasma = 0;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }
  
  Future<void> _fetchUserData() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .get();
      
      if (snapshot.exists) {
        Map<String, dynamic> userData = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _currentCoins = userData['StarryCoin'] ?? 0;
          _currentPlasma = userData['StarryPlasma'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _purchasePlasma(int plasmaAmount, int coinCost) async {
    // Check if user has enough coins
    if (_currentCoins < coinCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate("not_enough_coins")),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Show confirmation dialog
    bool? shouldPurchase = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate("confirm_purchase")),
        content: Text(
          AppLocalizations.of(context)!.translate("confirm_plasma_purchase_message")
            .replaceAll("{0}", plasmaAmount.toString())
            .replaceAll("{1}", coinCost.toString())
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(AppLocalizations.of(context)!.translate("cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(AppLocalizations.of(context)!.translate("confirm")),
          ),
        ],
      ),
    );
    
    if (shouldPurchase != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Get current data again to ensure accuracy
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .get();
      
      if (snapshot.exists) {
        Map<String, dynamic> userData = snapshot.data() as Map<String, dynamic>;
        int currentCoins = userData['StarryCoin'] ?? 0;
        int currentPlasma = userData['StarryPlasma'] ?? 0;
        
        if (currentCoins < coinCost) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.translate("not_enough_coins")),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
        
        int newCoins = currentCoins - coinCost;
        int newPlasma = currentPlasma + plasmaAmount;
        
        // Update in Firestore
        await FirebaseFirestore.instance
            .collection('starrymatch_user')
            .doc(widget.userId)
            .update({
              'StarryCoin': newCoins,
              'StarryPlasma': newPlasma,
            });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.translate("plasma_purchase_success")
                .replaceAll("{0}", plasmaAmount.toString())
                .replaceAll("{1}", newPlasma.toString())
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // Update local state
        setState(() {
          _currentCoins = newCoins;
          _currentPlasma = newPlasma;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error purchasing plasma: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate("purchase_error")),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }
  
  Widget _buildPlasmaPackage(int plasmaAmount, int coinCost) {
    return GestureDetector(
      onTap: () => _purchasePlasma(plasmaAmount, coinCost),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.28,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: _currentCoins >= coinCost 
              ? Border.all(color: Colors.purple, width: 2)
              : Border.all(color: Colors.grey.shade400, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/Coin/Starry Plasma.png",
              width: 40,
              height: 40,
            ),
            const SizedBox(height: 8),
            Text(
              plasmaAmount.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/Coin/Starry Coin.png",
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  coinCost.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _currentCoins >= coinCost 
                        ? Colors.deepPurple
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final bgImage = themeExt?.bgMain ?? 'assets/bg_pastel_main.jpg';
    
    return WillPopScope(
      // When the user presses back, pop with result = true to refresh data
      onWillPop: () async {
        Navigator.pop(context, true);
        return false; // Don't use default back button behavior
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.translate("plasma_purchase_title")),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, true); // Return true to indicate that data should be refreshed
            },
          ),
        ),
        body: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset(
                bgImage,
                fit: BoxFit.cover,
              ),
            ),
            
            // Content
            SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        // Current balances
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // Coins balance
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    "assets/Coin/Starry Coin.png",
                                    width: 30,
                                    height: 30,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    AppLocalizations.of(context)!.translate("current_coin_balance")
                                      .replaceAll("{0}", _currentCoins.toString()),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Plasma balance
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    "assets/Coin/Starry Plasma.png",
                                    width: 30,
                                    height: 30,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    AppLocalizations.of(context)!.translate("current_plasma_balance")
                                      .replaceAll("{0}", _currentPlasma.toString()),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Plasma packages
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            AppLocalizations.of(context)!.translate("select_plasma_package"),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        
                        // Plasma packages in row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildPlasmaPackage(10, 50),
                              _buildPlasmaPackage(30, 100),
                              _buildPlasmaPackage(100, 300),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Description
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.translate("plasma_description"),
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
