import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchQuestions(String testType) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('starrymatch_questions')
          .where('TestType', isEqualTo: testType) // Fetch either MBTI or Enneagram
          .get();
      return query.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error fetching questions: $e');
      return [];
    }
  }
}