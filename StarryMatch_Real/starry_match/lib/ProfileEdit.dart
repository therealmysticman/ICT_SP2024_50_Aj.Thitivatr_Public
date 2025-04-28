import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:starry_match/Dashboard.dart'; // Import Dashboard
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starry_match/localization/app_localizations.dart'; // Add import for AppLocalizations

class EditAvatarPage extends StatefulWidget {
  final String userId;

  const EditAvatarPage({super.key, required this.userId});
  @override
  _EditAvatarPageState createState() => _EditAvatarPageState();
}

class _EditAvatarPageState extends State<EditAvatarPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? selectedSkin;
  String? selectedHat;
  String? selectedClothes;
  List<String> ownedSkins = [];
  List<String> ownedHats = [];
  List<String> ownedClothes = [];
  
  // Lists to store accessory info from Firestore
  List<Map<String, dynamic>> skinAccessories = [];
  List<Map<String, dynamic>> hatAccessories = [];
  List<Map<String, dynamic>> clothesAccessories = [];
  
  String languageCode = "en"; // Default language

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _fetchUserAvatarData();
    _fetchAccessories();
  }
  
  Future<void> _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      languageCode = prefs.getString('language') ?? "en";
    });
  }

  void _fetchUserAvatarData() async {
    String uid = _auth.currentUser!.uid;
    DocumentSnapshot userDoc =
        await _firestore.collection('starrymatch_user').doc(uid).get();

    if (userDoc.exists) {
      var data = userDoc['UserAvatar'];
      setState(() {
        selectedSkin = data['selectedSkin'] ?? "";
        selectedHat = data['selectedHat'] ?? "";
        selectedClothes = data['selectedClothes'] ?? "";
        ownedSkins = List<String>.from(data['ownedSkins'] ?? []);
        ownedHats = List<String>.from(data['ownedHats'] ?? []);
        ownedClothes = List<String>.from(data['ownedClothes'] ?? []);
      });
    }
  }
  
  Future<void> _fetchAccessories() async {
    // Determine collection name based on language
    String collectionName = languageCode == 'th' 
        ? 'starrymatch_th_accessories' 
        : 'starrymatch_accessories';
    
    // Maps to normalize categories
    final Map<String, String> thToEnCategoryMap = {
      'หมวก': 'Hat',
      'สกิน': 'Skins',
      'เสื้อผ้า': 'Clothes',
    };
    
    try {
      QuerySnapshot snapshot = await _firestore.collection(collectionName).get();
      
      // Temporary lists to populate
      List<Map<String, dynamic>> skins = [];
      List<Map<String, dynamic>> hats = [];
      List<Map<String, dynamic>> clothes = [];
      
      for (var doc in snapshot.docs) {
        String category = doc['AccessoriesType'] ?? 'Unknown';
        
        // Normalize Thai categories to English for internal processing
        if (languageCode == 'th') {
          category = thToEnCategoryMap[category] ?? category;
        }
        
        // Create accessory item
        Map<String, dynamic> accessory = {
          'name': doc['AccessoriesName'] ?? 'No Name',
          'image': doc['AccessoriesPic'] ?? 'default.png',
          'category': category,
        };
        
        // Add to appropriate list based on category
        if (category == 'Skins') {
          skins.add(accessory);
        } else if (category == 'Hat') {
          hats.add(accessory);
        } else if (category == 'Clothes') {
          clothes.add(accessory);
        }
      }
      
      // Update state with fetched accessories
      setState(() {
        skinAccessories = skins;
        hatAccessories = hats;
        clothesAccessories = clothes;
      });
    } catch (e) {
      print("Error fetching accessories: $e");
    }
  }

  void _updateAvatar() async {
    String uid = _auth.currentUser!.uid;
    await _firestore.collection('starrymatch_user').doc(uid).update({
      'UserAvatar.selectedSkin': selectedSkin,
      'UserAvatar.selectedHat': selectedHat,
      'UserAvatar.selectedClothes': selectedClothes,
    });
  }

  Widget _buildAccessoriesGrid(
    List<Map<String, dynamic>> accessories,
    List<String> ownedItems,
    String? selectedItem,
    Function(String) onSelect,
    String itemType,
  ) {
    // Filter to only show owned items
    final List<Map<String, dynamic>> filteredItems = accessories.where((item) => 
      ownedItems.contains(item['name'])
    ).toList();
    
    // Add a "None" option for hats and clothes
    if (itemType != "Skins") {
      filteredItems.insert(0, {
        'name': "",
        'image': "default.png",
        'category': itemType,
      });
    }
    
    // If no items are available, show a message
    if (filteredItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "No items available",
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    // คำนวณขนาดของแต่ละไอเทม
    const double itemWidth = 130.0;
    const double itemHeight = 180.0;
    
    // สร้าง ListView แนวนอน
    return Container(
      height: itemHeight,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListView.builder(
        scrollDirection: Axis.horizontal, // ให้เลื่อนในแนวนอน
        itemCount: filteredItems.length,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        itemBuilder: (context, index) {
          final item = filteredItems[index];
          final isSelected = selectedItem == item['name'];
          
          // Determine asset path based on item type
          String assetPath;
          if (itemType == "Skins") {
            assetPath = 'assets/Avatar/Skin/${item['name']}.png';
          } else if (itemType == "Hat") {
            assetPath = item['name'].isEmpty
                ? 'assets/Avatar/Decoration/Accessories/default_hat.png'  // Show empty slot for "None" option
                : 'assets/Avatar/Decoration/Accessories/${item['name']}.png';
          } else { // Clothes
            assetPath = item['name'].isEmpty
                ? 'assets/Avatar/Decoration/Clothing/default_clothes.png'  // Show empty slot for "None" option
                : 'assets/Avatar/Decoration/Clothing/${item['name']}.png';
          }
          
          return Container(
            width: itemWidth,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: isSelected
                    ? const BorderSide(color: Colors.white, width: 2)
                    : BorderSide.none,
              ),
              color: isSelected
                  ? Theme.of(context).colorScheme.secondaryFixed// สีม่วงอ่อนเมื่อเลือก
                  : Theme.of(context).colorScheme.surfaceDim,    // สีม่วงเข้มปกติ
              child: InkWell(
                onTap: () => onSelect(item['name']),
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Item image
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 2),
                          child: Image.asset(
                            assetPath,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    // Item name
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                      child: Text(
                        item['name'].isEmpty 
                            ? itemType == "Hat" 
                                ? AppLocalizations.of(context)?.translate("none") ?? "None"
                                : AppLocalizations.of(context)?.translate("none") ?? "None"
                            : item['name'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary  // White color when selected
                              : Theme.of(context).colorScheme.primaryFixed,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // คำนวณขนาดหน้าจอเพื่อปรับขนาดตามความกว้างจอ
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isVerySmallScreen = screenSize.width < 320;
    
    // กำหนดขนาดและตำแหน่งแบบ responsive
    final bannerHeight = isVerySmallScreen ? 180.0 : (isSmallScreen ? 220.0 : 250.0);
    final avatarWidth = isVerySmallScreen ? 100.0 : (isSmallScreen ? 120.0 : 150.0);
    final stageWidth = isVerySmallScreen ? 120.0 : (isSmallScreen ? 150.0 : 180.0);
    final avatarTop = isVerySmallScreen ? 30.0 : (isSmallScreen ? 40.0 : 50.0);
    final stageBannerCut = isVerySmallScreen ? -40.0 : (isSmallScreen ? -50.0 : -60.0); // ค่าที่ stage จะถูกตัดโดย banner
    
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)?.translate("edit_avatar") ?? "Edit Avatar"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => DashboardPage(userId: widget.userId)),
              );
            },
          ),
        ),
        body: Stack(
          children: [
            // Background color
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface, // Light gray background color
              ),
              width: double.infinity,
              height: double.infinity,
            ),
            
            // Content
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal:0, vertical: 1.0),
                child: Column(
                  children: [
                    // ✅ Banner with Proper Layering
                    Container(
                      height: bannerHeight,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          // ✅ 1. Background Banner (Lowest Layer)
                          Positioned.fill(
                            child: Image.asset(
                              'assets/banner_edit.png',
                              fit: BoxFit.cover,
                            ),
                          ),

                          // ✅ 2. Stage (อยู่ระหว่าง Banner และ Avatar)
                          Positioned(
                            bottom: 0, // ให้ stage อยู่ชิดด้านล่างของ banner
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Image.asset(
                                'assets/stage_edit.png',
                                width: stageWidth,
                              ),
                            ),
                          ),

                          // ✅ 3. Avatar with accessories (อยู่ด้านบนสุด ลอยเหนือ Stage)
                          Positioned(
                            bottom: 60, // ปรับตำแหน่งให้อวตารลอยอยู่เหนือ stage
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Base skin
                                  Image.asset(
                                    'assets/Avatar/Skin/${selectedSkin ?? "Travel light"}.png',
                                    width: avatarWidth,
                                    height: avatarWidth,
                                  ),
                                  
                                  // Hat accessory (if any)
                                  if (selectedHat != null && selectedHat!.isNotEmpty)
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: Image.asset(
                                          'assets/Avatar/Decoration/Accessories/$selectedHat.png',
                                          width: avatarWidth,
                                        ),
                                      ),
                                    ),
                                  
                                  // Clothing accessory (if any)
                                  if (selectedClothes != null && selectedClothes!.isNotEmpty)
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: Image.asset(
                                          'assets/Avatar/Decoration/Clothing/$selectedClothes.png',
                                          width: avatarWidth,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ Selection UI (Grid view of accessories)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        children: [
                          Text(
                            AppLocalizations.of(context)?.translate("select_skin") ?? "Select Skin",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                          ),
                          const SizedBox(height: 10),
                          _buildAccessoriesGrid(
                            skinAccessories, 
                            ownedSkins, 
                            selectedSkin ?? "", 
                            (val) => setState(() => selectedSkin = val),
                            "Skins"
                          ),
                          
                          const SizedBox(height: 20),
                          Text(
                            AppLocalizations.of(context)?.translate("select_hat") ?? "Select Hat",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                          ),
                          const SizedBox(height: 10),
                          _buildAccessoriesGrid(
                            hatAccessories, 
                            ownedHats, 
                            selectedHat ?? "", 
                            (val) => setState(() => selectedHat = val),
                            "Hat"
                          ),
                          
                          const SizedBox(height: 20),
                          Text(
                            AppLocalizations.of(context)?.translate("select_clothes") ?? "Select Clothes",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                          ),
                          const SizedBox(height: 10),
                          _buildAccessoriesGrid(
                            clothesAccessories, 
                            ownedClothes, 
                            selectedClothes ?? "", 
                            (val) => setState(() => selectedClothes = val),
                            "Clothes"
                          ),
                          
                          const SizedBox(height: 30),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                            onPressed: () {
                              _updateAvatar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(
                                  AppLocalizations.of(context)?.translate("avatar_updated") ?? "Avatar Updated!"
                                ))
                              );
                            },
                            child: Text(AppLocalizations.of(context)?.translate("save_changes") ?? "Save Changes"),
                          ),
                          // เพิ่ม spacing ด้านล่างสุดเพื่อให้มีพื้นที่พอเพียงเมื่อเลื่อนหน้าจอ
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ));
  }
}
