import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchQuestions(String testType) async {
    try {
      // Get user's language preference
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String languageCode = prefs.getString('language') ?? 'en'; // Default to English

      // Choose the correct collection based on the language
      String collectionName = (languageCode == 'th')
          ? 'starrymatch_th_questions'
          : 'starrymatch_questions';

      QuerySnapshot query = await _firestore
          .collection(collectionName)
          .where('TestType', isEqualTo: testType) // Fetch either MBTI or Enneagram
          .get();
          
      return query.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error fetching questions: $e');
      return [];
    }
  }
}
