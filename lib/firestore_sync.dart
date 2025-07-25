import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreSync {
  static final _db = FirebaseFirestore.instance;

  // 上傳熟悉單字進度
  static Future<void> uploadKnownWords(List<String> knownWords) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'knownWords': knownWords,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 上傳收藏單字
  static Future<void> uploadFavorites(List<String> favorites) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'favorites': favorites,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 上傳測驗紀錄
  static Future<void> uploadQuizRecord(Map<String, dynamic> quizRecord) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid)
      .collection('quizRecords').add(quizRecord);
  }

  // 下載所有雲端資料（進度、收藏、測驗）
  static Future<Map<String, dynamic>?> downloadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userDocRef = _db.collection('users').doc(user.uid);
    final doc = await userDocRef.get();

    // 如果使用者文件不存在，為新用戶建立一個初始文件
    if (!doc.exists) {
      final initialData = {
        'knownWords': [],
        'favorites': [],
        'createdAt': FieldValue.serverTimestamp(),
      };
      await userDocRef.set(initialData);
      // 返回新建的初始資料
      return {
        'knownWords': [],
        'favorites': [],
        'quizRecords': [],
      };
    }

    // 如果文件存在，正常讀取資料
    final quizSnapshots = await userDocRef
        .collection('quizRecords')
        .orderBy('timestamp', descending: true)
        .get();

    return {
      'knownWords': doc.data()?['knownWords'] ?? [],
      'favorites': doc.data()?['favorites'] ?? [],
      'quizRecords': quizSnapshots.docs.map((d) => d.data()).toList(),
    };
  }
}
