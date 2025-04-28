import 'package:flutter/material.dart';
import 'package:starry_match/CoinsPurchase.dart';
import 'package:starry_match/localization/app_localizations.dart';
import 'package:starry_match/theme/AppThemeExtension.dart';
import 'package:starry_match/widgets/bottomnav_widget.dart';
import 'package:starry_match/services/accessories_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorePage extends StatefulWidget {
  final String userId;
  const StorePage({super.key, required this.userId});

  @override
  _StorePageState createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  int _selectedIndex = 3;
  String selectedCategory = 'All';

  List<Map<String, dynamic>> items = [];
  List<String> ownedSkins = [];
  List<String> ownedHats = [];
  List<String> ownedClothes = [];

  // ✅ Temporary preview selections
  String? previewSkin;
  String? previewHat;
  String? previewClothes;

  final AccessoriesService _accessoriesService = AccessoriesService();
  String languageCode = "en"; // Default to English
  
  // Map to translate category names between languages
  Map<String, String> enToThCategoryMap = {
    'Hat': 'หมวก',
    'Skins': 'สกิน',
    'Clothes': 'เสื้อผ้า',
  };
  
  Map<String, String> thToEnCategoryMap = {
    'หมวก': 'Hat',
    'สกิน': 'Skins',
    'เสื้อผ้า': 'Clothes',
  };

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    fetchAccessories();
  }
  
  Future<void> _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      languageCode = prefs.getString('language') ?? "en";
    });
  }

  Future<void> fetchAccessories() async {
    // Pass language code to service
    List<Map<String, dynamic>> fetchedItems =
        await _accessoriesService.fetchAccessories(languageCode: languageCode);
    setState(() {
      items = fetchedItems;
    });
  }

  List<Map<String, dynamic>> getFilteredItems() {
    List<Map<String, dynamic>> filteredItems;

    if (selectedCategory == 'All') {
      filteredItems = items;
    } else {
      filteredItems =
          items.where((item) => item['category'] == selectedCategory).toList();
    }

    filteredItems.sort((a, b) {
      bool aOwned = isItemOwned(a);
      bool bOwned = isItemOwned(b);

      if (aOwned && !bOwned) {
        return 1;
      } else if (!aOwned && bOwned) {
        return -1;
      } else {
        return 0;
      }
    });

    return filteredItems;
  }

  bool isItemOwned(Map<String, dynamic> item) {
    if (item['category'] == 'Skins') return ownedSkins.contains(item['name']);
    if (item['category'] == 'Hat') return ownedHats.contains(item['name']);
    if (item['category'] == 'Clothes') {
      return ownedClothes.contains(item['name']);
    }
    return false;
  }

  // ✅ Toggle preview when clicking on a product box
  void togglePreview(Map<String, dynamic> item) {
    setState(() {
      String category = item['category'];
      String itemName = item['name'];

      if (category == 'Skins') {
        previewSkin = (previewSkin == itemName) ? null : itemName;
      } else if (category == 'Hat') {
        previewHat = (previewHat == itemName) ? null : itemName;
      } else if (category == 'Clothes') {
        previewClothes = (previewClothes == itemName) ? null : itemName;
      }
    });
  }

  // Add this function to handle purchases
  Future<void> _purchaseItem(Map<String, dynamic> item) async {
    // Get current user data
    final userDoc = await FirebaseFirestore.instance
        .collection("starrymatch_user")
        .doc(widget.userId)
        .get();
    
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final int userCoins = userData['StarryCoin'] ?? 0;
    final int itemPrice = item['price'] as int;
    
    // Check if user has enough coins
    if (userCoins < itemPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate("not_enough_coins") ?? 
                        "Not enough coins! You need ${itemPrice - userCoins} more coins."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Show confirmation dialog
    bool confirmPurchase = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(languageCode == "th" ? "ยืนยันการซื้อ" : "Confirm Purchase"),
          content: Text(
            languageCode == "th" 
              ? "คุณแน่ใจที่จะซื้อ ${item['name']} ในราคา ${item['price']} Starry coins หรือไม่?"
              : "Are you sure you want to buy ${item['name']} for ${item['price']} coins?"
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              child: Text(languageCode == "th" ? "ยกเลิก" : "Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              child: Text(languageCode == "th" ? "ซื้อ" : "Buy"),
            ),
          ],
        );
      },
    ) ?? false;
    
    if (!confirmPurchase) return;
    
    // Process the purchase
    try {
      // Update user data in Firestore
      final int newCoinBalance = userCoins - itemPrice;
      
      // Determine which owned items collection to update based on item category
      String ownedCollectionField;
      List<String> currentOwnedItems;
      
      switch (item['category']) {
        case 'Skins':
          ownedCollectionField = 'UserAvatar.ownedSkins';
          currentOwnedItems = ownedSkins;
          break;
        case 'Hat':
          ownedCollectionField = 'UserAvatar.ownedHats';
          currentOwnedItems = ownedHats;
          break;
        case 'Clothes':
          ownedCollectionField = 'UserAvatar.ownedClothes';
          currentOwnedItems = ownedClothes;
          break;
        default:
          throw Exception("Unknown item category");
      }
      
      // Add to owned items if not already owned
      if (!currentOwnedItems.contains(item['name'])) {
        currentOwnedItems.add(item['name']);
        
        // Update Firestore
        await FirebaseFirestore.instance
            .collection("starrymatch_user")
            .doc(widget.userId)
            .update({
              'StarryCoin': newCoinBalance,
              ownedCollectionField: currentOwnedItems,
            });
            
        // Update local state
        setState(() {
          if (item['category'] == 'Skins') ownedSkins = currentOwnedItems;
          if (item['category'] == 'Hat') ownedHats = currentOwnedItems;
          if (item['category'] == 'Clothes') ownedClothes = currentOwnedItems;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${AppLocalizations.of(context)!.translate("purchased") ?? "Successfully purchased"} ${item['name']}!"),
          ),
        );
        
        // ✅ Ask user if they want to wear the item immediately
        bool wearImmediately = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(languageCode == "th" ? "ต้องการสวมใส่เลยไหม?" : "Wear it now?"),
              content: Text(
                languageCode == "th" 
                  ? "คุณต้องการสวมใส่ ${item['name']} ทันทีหรือไม่?"
                  : "Do you want to wear ${item['name']} right now?"
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: Text(languageCode == "th" ? "ไม่เดี๋ยวค่อยใส่" : "Not now"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: Text(languageCode == "th" ? "ใส่เลย" : "Wear now"),
                ),
              ],
            );
          },
        ) ?? false;
        
        // If user wants to wear the item immediately, update selected item
        if (wearImmediately) {
          String selectedField;
          
          switch (item['category']) {
            case 'Skins':
              selectedField = 'UserAvatar.selectedSkin';
              setState(() {
                previewSkin = item['name'];
              });
              break;
            case 'Hat':
              selectedField = 'UserAvatar.selectedHat';
              setState(() {
                previewHat = item['name'];
              });
              break;
            case 'Clothes':
              selectedField = 'UserAvatar.selectedClothes';
              setState(() {
                previewClothes = item['name'];
              });
              break;
            default:
              throw Exception("Unknown item category");
          }
          
          // Update Firestore with the selected item
          await FirebaseFirestore.instance
              .collection("starrymatch_user")
              .doc(widget.userId)
              .update({
                selectedField: item['name'],
              });
        }
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${AppLocalizations.of(context)!.translate("error_purchasing") ?? "Error purchasing item:"} $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<AppThemeExtension>();
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isVerySmallScreen = screenSize.width < 320;
    // Significantly reduce banner height for small screens based on logs showing excessive vertical scrolling
    final bannerHeight = isVerySmallScreen ? 120.0 : (isSmallScreen ? 140.0 : 200.0);
    final avatarWidth = isVerySmallScreen ? 60.0 : (isSmallScreen ? 70.0 : 110.0);
    final stageWidth = isVerySmallScreen ? 75.0 : (isSmallScreen ? 90.0 : 120.0);
    final stageTop = isVerySmallScreen ? 80.0 : (isSmallScreen ? 100.0 : 140.0);
    final avatarTop = isVerySmallScreen ? 30.0 : (isSmallScreen ? 40.0 : 50.0);
    final buttonPadding = isSmallScreen ? 1.0 : 3.0;
    final buttonFontSize = isSmallScreen ? 10.0 : 12.0;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.translate("store_title")),
      ),
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface, // Light gray background color
            ),
            width: double.infinity,
            height: double.infinity,
          ),
          
          // Existing content
          StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("starrymatch_user")
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          var userAvatar = userData['UserAvatar'] ?? {};

          // ✅ Use preview if set, otherwise fallback to Firestore selection
          String selectedSkin =
              previewSkin ?? userAvatar['selectedSkin'] ?? 'default_skin';
          String selectedHat = previewHat ?? userAvatar['selectedHat'] ?? '';
          String selectedClothes =
              previewClothes ?? userAvatar['selectedClothes'] ?? '';

          ownedSkins = List<String>.from(userAvatar['ownedSkins'] ?? []);
          ownedHats = List<String>.from(userAvatar['ownedHats'] ?? []);
          ownedClothes = List<String>.from(userAvatar['ownedClothes'] ?? []);

          return Column(
            children: [
              // ✅ Banner with previewed Avatar
              Stack(
                alignment: Alignment.center,
                children: [
                  // ✅ 1. Background Banner (Lowest Layer)
                  SizedBox(
                        height: bannerHeight,
                    width: double.infinity,
                    child: Image.asset('assets/banner_store.PNG',
                        fit: BoxFit.cover),
                  ),

                  // ✅ 2. Stage (Placed BEHIND Avatar)
                  Positioned(
                        top: stageTop, // Adjusted to fit right under the avatar's feet
                    child: Image.asset(
                      'assets/stage_store.PNG',
                          width: stageWidth, // Adjust width to align with the avatar
                    ),
                  ),
                  // ✅ 2. Starry Coins (Top-right, Clickable)
Positioned(
  top: 15, // Adjust position
  right: 20, // Move to top-right corner
  child: GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CoinsPurchasePage(userId: widget.userId)),
      );
    },
    child: Row(
      children: [
        Image.asset(
          'assets/Coin/Starry Coin.png', // Ensure this asset exists
          width: 24,
          height: 24,
        ),
        const SizedBox(width: 5),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("starrymatch_user")
              .doc(widget.userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.hasError) {
              return const Text("0", style: TextStyle(fontSize: 16 , color: Colors.white));
            }
            var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            int coins = userData['StarryCoin'] ?? 0;
            return Text(
              coins.toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold , color: Colors.white),
            );
          },
        ),
      ],
    ),
  ),
),
                  // ✅ Improved Avatar Placement & Size
                  Positioned(
                        top: avatarTop, // Adjusted to center inside the banner shelf
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // ✅ Larger Avatar Size
                        Image.asset(
                          'assets/Avatar/Skin/$selectedSkin.png',
                              width: avatarWidth, // Responsive size
                        ),

                        // ✅ Properly Positioned Hat
                        if (selectedHat.isNotEmpty)
                          Positioned(
                            top:
                                0, // Move it higher to fit naturally on the head
                            child: Image.asset(
                              'assets/Avatar/Decoration/Accessories/$selectedHat.png',
                                  width: avatarWidth, // Match avatar scale
                            ),
                          ),

                        // ✅ Properly Positioned Clothes
                        if (selectedClothes.isNotEmpty)
                          Positioned(
                            bottom:
                                0, // Move it lower to fit naturally on the avatar
                            child: Image.asset(
                              'assets/Avatar/Decoration/Clothing/$selectedClothes.png',
                                  width: avatarWidth, // Match avatar scale
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Padding(
                    padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4.0 : 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                          for (var category in languageCode == "th" 
                            ? ['ทั้งหมด', 'หมวก', 'เสื้อผ้า', 'สกิน']
                            : ['All', 'Hat', 'Clothes', 'Skins'])
                      Padding(
                              padding: EdgeInsets.symmetric(horizontal: buttonPadding),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                                    // Convert Thai categories to English for internal filtering
                                    if (languageCode == "th") {
                                      if (category == 'ทั้งหมด') {
                                        selectedCategory = 'All';
                                      } else {
                                        selectedCategory = thToEnCategoryMap[category] ?? category;
                                      }
                                    } else {
                              selectedCategory = category;
                                    }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                                  backgroundColor: (languageCode == "th")
                                      ? (category == 'ทั้งหมด' && selectedCategory == 'All') 
                                        || (thToEnCategoryMap[category] == selectedCategory)
                                          ? const Color.fromARGB(255, 250, 205, 92)
                                          : const Color.fromARGB(255, 191, 179, 193)
                                      : (category == selectedCategory)
                                          ? const Color.fromARGB(255, 250, 205, 92)
                                          : const Color.fromARGB(255, 191, 179, 193),
                                  foregroundColor: (languageCode == "th")
                                      ? (category == 'ทั้งหมด' && selectedCategory == 'All') 
                                        || (thToEnCategoryMap[category] == selectedCategory)
                                          ? const Color.fromARGB(255, 62, 42, 15)
                                          : const Color.fromARGB(255, 106, 74, 110)
                                      : (category == selectedCategory)
                                          ? const Color.fromARGB(255, 62, 42, 15)
                                          : const Color.fromARGB(255, 106, 74, 110),
                                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 6.0 : 10.0, vertical: isSmallScreen ? 6.0 : 8.0),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(fontSize: buttonFontSize),
                                ),
                        ),
                      ),
                  ],
                      ),
                ),
              ),

              // ✅ Store Items with Toggle Feature
              // ✅ Store Items with Hover Toggle
              Expanded(
                child: items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                        : Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            padding: EdgeInsets.only(
                              top: isSmallScreen ? 8.0 : 15.0, 
                              left: isSmallScreen ? 5.0 : 10.0, 
                              right: isSmallScreen ? 5.0 : 10.0
                            ),
                            child: GridView.builder(
                              padding: EdgeInsets.all(isSmallScreen ? 5.0 : 10.0),
                        gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                                crossAxisSpacing: isSmallScreen ? 5.0 : 10.0,
                                mainAxisSpacing: isSmallScreen ? 5.0 : 10.0,
                                childAspectRatio: isVerySmallScreen ? 0.65 : (isSmallScreen ? 0.7 : 0.8),
                        ),
                        itemCount: getFilteredItems().length,
                        itemBuilder: (context, index) {
                          final item = getFilteredItems()[index];
                          bool isOwned = isItemOwned(item);
                          bool isPreviewing = (previewSkin == item['name'] ||
                              previewHat == item['name'] ||
                              previewClothes == item['name']);

                          return GestureDetector(
                            onTap: () => togglePreview(item),
                            child: Card(
                              color: isPreviewing
                                        ? Theme.of(context).colorScheme.secondary
                                        : Theme.of(context).colorScheme.primary,
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isPreviewing 
                                            ? Theme.of(context).colorScheme.primary 
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        isOwned
                                          ? Expanded(
                                              child: Center(
                                                child: Stack(
                                                  alignment: Alignment.topCenter,
                                                  children: [
                                                    // รูปภาพของไอเทม
                                                    Image.asset(
                                                      item['image'],
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Expanded(
                                              child: Center(
                                                child: Stack(
                                                  alignment: Alignment.topCenter,
                                                  children: [
                                                    // รูปภาพของไอเทม
                                                    Image.asset(
                                                      item['image'],
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        // แสดงคำว่า "กำลังลอง/TRYING" ด้านล่างรูปแต่อยู่เหนือชื่อและราคา
                                        if (isPreviewing)
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            margin: EdgeInsets.only(bottom: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD2B048), // Gold color like in reference
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              languageCode == 'th' ? 'กำลังลอง' : 'TRYING',
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 10.0 : 12.0,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: EdgeInsets.all(isSmallScreen ? 4.0 : 8.0),
                                          child: Column(
                                            children: [
                                              Text(
                                                item['name'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: isSmallScreen ? 11.0 : 13.0,
                                                  color: isPreviewing 
                                                    ? Theme.of(context).colorScheme.tertiary
                                                    : Theme.of(context).colorScheme.onPrimary,
                                                )
                                              ),
                                              Text(
                                                languageCode == 'th' ? 'ราคา: ${item['price']}' : 'Price: ${item['price']}',
                                                style: TextStyle(
                                                  fontSize: isSmallScreen ? 10.0 : 12.0,
                                                  color: isPreviewing 
                                                    ? Theme.of(context).colorScheme.tertiary.withOpacity(0.8)
                                                    : Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                                                ),
                                              ),
                                              SizedBox(height: isSmallScreen ? 3.0 : 5.0),
                                              isOwned
                                                  ? Container(
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal: isSmallScreen ? 8.0 : 12.0, 
                                                        vertical: isSmallScreen ? 4.0 : 8.0
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isPreviewing
                                                          ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                                                          : Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: InkWell(
                                                        onTap: () async {
                                                          // ตรวจสอบว่าไอเทมกำลังถูกใช้งานอยู่หรือไม่
                                                          bool isCurrentlyEquipped = false;
                                                          String selectedField;
                                                          
                                                          switch (item['category']) {
                                                            case 'Skins':
                                                              isCurrentlyEquipped = userAvatar['selectedSkin'] == item['name'];
                                                              selectedField = 'UserAvatar.selectedSkin';
                                                              // ถ้ากำลังสวมใส่อยู่แล้ว ไม่ต้องทำอะไร
                                                              if (isCurrentlyEquipped) return;
                                                              // อัพเดต UI และ Firestore
                                                              setState(() {
                                                                previewSkin = item['name'];
                                                              });
                                                              break;
                                                            case 'Hat':
                                                              isCurrentlyEquipped = userAvatar['selectedHat'] == item['name'];
                                                              selectedField = 'UserAvatar.selectedHat';
                                                              // ถ้ากำลังสวมใส่อยู่แล้ว ไม่ต้องทำอะไร
                                                              if (isCurrentlyEquipped) return;
                                                              // อัพเดต UI และ Firestore
                                                              setState(() {
                                                                previewHat = item['name'];
                                                              });
                                                              break;
                                                            case 'Clothes':
                                                              isCurrentlyEquipped = userAvatar['selectedClothes'] == item['name'];
                                                              selectedField = 'UserAvatar.selectedClothes';
                                                              // ถ้ากำลังสวมใส่อยู่แล้ว ไม่ต้องทำอะไร
                                                              if (isCurrentlyEquipped) return;
                                                              // อัพเดต UI และ Firestore
                                                              setState(() {
                                                                previewClothes = item['name'];
                                                              });
                                                              break;
                                                            default:
                                                              return;
                                                          }
                                                          
                                                          // บันทึกการเปลี่ยนแปลงลงใน Firestore
                                                          await FirebaseFirestore.instance
                                                              .collection("starrymatch_user")
                                                              .doc(widget.userId)
                                                              .update({
                                                                selectedField: item['name'],
                                                              });
                                                          
                                                          // แสดงข้อความแจ้งเตือน
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text(languageCode == "th" ? 
                                                                "สวมใส่ ${item['name']} แล้ว" : 
                                                                "Equipped ${item['name']}"),
                                                              duration: const Duration(seconds: 1),
                                                            ),
                                                          );
                                                        },
                                                        child: Text(
                                                          // ตรวจสอบว่าไอเทมกำลังถูกใช้งานอยู่หรือไม่ (โดยไม่สนใจสถานะ preview)
                                                          (
                                                            // ไอเทมที่กำลังสวมใส่อยู่ (จริง ๆ)
                                                            (userAvatar['selectedSkin'] == item['name'] && item['category'] == 'Skins') ||
                                                            (userAvatar['selectedHat'] == item['name'] && item['category'] == 'Hat') ||
                                                            (userAvatar['selectedClothes'] == item['name'] && item['category'] == 'Clothes')
                                                          )
                                                          ? (languageCode == "th" ? "กำลังใส่" : "EQUIPPED")
                                                          : (languageCode == "th" ? "สวมใส่" : "EQUIP NOW"),
                                                          style: TextStyle(
                                                            fontSize: isSmallScreen ? 10.0 : 12.0,
                                                            color: isPreviewing
                                                              ? Theme.of(context).colorScheme.onSurface
                                                              : Theme.of(context).colorScheme.onPrimary,
                                                            fontWeight: FontWeight.bold
                                                          ),
                                                        ),
                                                      ),
                                              )
                                            : ElevatedButton(
                                                onPressed: () {
                                                        _purchaseItem(item);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                        backgroundColor: Theme.of(context).colorScheme.secondary,
                                                        foregroundColor: Theme.of(context).colorScheme.tertiary,
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: isSmallScreen ? 8.0 : 12.0, 
                                                          vertical: isSmallScreen ? 4.0 : 8.0
                                                        ),
                                                        minimumSize: const Size(30, 0),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        languageCode == "th" ? "ซื้อ" : "BUY",
                                                        style: TextStyle(fontSize: isSmallScreen ? 10.0 : 12.0),
                                                      ),
                                              ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                            ),
                      ),
              ),
            ],
          );
        },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavWidget(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        userId: widget.userId,
      ),
    );
  }
}
