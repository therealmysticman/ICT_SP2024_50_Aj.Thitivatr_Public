import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/localization/app_localizations.dart';

class CoinsPurchasePage extends StatefulWidget {
  final String userId;

  const CoinsPurchasePage({super.key, required this.userId});
  
  @override
  State<CoinsPurchasePage> createState() => _CoinsPurchasePageState();
}

class _CoinsPurchasePageState extends State<CoinsPurchasePage> {
  int _currentCoins = 0;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchCurrentCoins();
  }
  
  Future<void> _fetchCurrentCoins() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .get();
      
      if (snapshot.exists) {
        setState(() {
          _currentCoins = (snapshot.data() as Map<String, dynamic>)['StarryCoin'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching user coins: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _addCoins(int amount) async {
    // Show confirmation dialog
    bool? shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate("confirm_purchase")),
        content: Text(AppLocalizations.of(context)!.translate("confirm_purchase_message").replaceAll("{0}", amount.toString())),
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
    
    if (shouldAdd != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Get current coins again to ensure accuracy
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('starrymatch_user')
          .doc(widget.userId)
          .get();
      
      if (snapshot.exists) {
        int currentCoins = (snapshot.data() as Map<String, dynamic>)['StarryCoin'] ?? 0;
        int newTotal = currentCoins + amount;
        
        // Update coins in Firestore
        await FirebaseFirestore.instance
            .collection('starrymatch_user')
            .doc(widget.userId)
            .update({'StarryCoin': newTotal});
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.translate("purchase_success")
                .replaceAll("{0}", amount.toString())
                .replaceAll("{1}", newTotal.toString())
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // Update local state
        setState(() {
          _currentCoins = newTotal;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error adding coins: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate("purchase_error")),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }
  
  Widget _buildCoinPackage({
    required int amount,
    required String price,
    String? descriptionKey,
    int? percentBonus,
    Color? color,
  }) {
    String description = '';
    if (descriptionKey != null && percentBonus != null) {
      description = AppLocalizations.of(context)!.translate(descriptionKey).replaceAll("{0}", percentBonus.toString());
    } else if (descriptionKey != null) {
      description = AppLocalizations.of(context)!.translate(descriptionKey);
    }
    
    return GestureDetector(
      onTap: () => _addCoins(amount),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? Colors.purple.shade100,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(
              "assets/Coin/Starry Coin.png",
              width: 60,
              height: 60,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.translate("coins_amount").replaceAll("{0}", amount.toString()),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                            color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              price,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
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
          title: Text(AppLocalizations.of(context)!.translate("coins_purchase_title")),
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
                        // Current balance
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                "assets/Coin/Starry Coin.png",
                                width: 40,
                                height: 40,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                AppLocalizations.of(context)!.translate("current_balance").replaceAll("{0}", _currentCoins.toString()),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Coin packages
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    AppLocalizations.of(context)!.translate("select_package"),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                _buildCoinPackage(
                                  amount: 50,
                                  price: "฿30",
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                _buildCoinPackage(
                                  amount: 100,
                                  price: "฿60",
                                  descriptionKey: "most_popular",
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                _buildCoinPackage(
                                  amount: 250,
                                  price: "฿150",
                                  descriptionKey: "more_coins",
                                  percentBonus: 25,
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                _buildCoinPackage(
                                  amount: 500,
                                  price: "฿299",
                                  descriptionKey: "best_value",
                                  percentBonus: 40,
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                _buildCoinPackage(
                                  amount: 1000,
                                  price: "฿599",
                                  descriptionKey: "premium_package",
                                  percentBonus: 50,
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                const SizedBox(height: 20),
                              ],
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
