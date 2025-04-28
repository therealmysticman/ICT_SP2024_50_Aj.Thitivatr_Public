import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessoriesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Maps to normalize categories from Thai to English
  final Map<String, String> thToEnCategoryMap = {
    'หมวก': 'Hat',
    'สกิน': 'Skins',
    'เสื้อผ้า': 'Clothes',
  };

  Future<List<Map<String, dynamic>>> fetchAccessories({String? languageCode}) async {
    // Determine language if not provided
    if (languageCode == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      languageCode = prefs.getString('language') ?? 'en';
    }
    
    // Select the appropriate collection based on language
    String collectionName = languageCode == 'th' 
        ? 'starrymatch_th_accessories' 
        : 'starrymatch_accessories';
    
    try {
      QuerySnapshot snapshot = await _firestore.collection(collectionName).get();
      return snapshot.docs.map((doc) {
        String category = doc['AccessoriesType'] ?? 'Unknown';
        
        // Normalize Thai categories to English for internal use
        if (languageCode == 'th') {
          category = thToEnCategoryMap[category] ?? category;
        }
        
        return {
          'name': doc['AccessoriesName'] ?? 'No Name',
          'price': doc['AccessoriesPrice'] ?? 0,
          'image': doc['AccessoriesPic'] ?? 'default.png',
          'category': category, // Normalized category
          'original_category': doc['AccessoriesType'] ?? 'Unknown', // Original category name
          'description': doc['AccessoriesDesc'] ?? 'No Description'
        };
      }).toList();
    } catch (e) {
      print("Error fetching accessories: $e");
      return [];
    }
  }
}
