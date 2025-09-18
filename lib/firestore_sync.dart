import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreSync {
  static final _db = FirebaseFirestore.instance;

  // 舊版（整體 knownWords）仍保留，避免相容性問題；新版本請用 uploadKnownWordsForLevel
  static Future<void> uploadKnownWords(List<String> knownWords) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'knownWords': knownWords,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 以等級為單位上傳熟悉單字進度：寫入 nested 欄位 knownByLevel.<level>
  static Future<void> uploadKnownWordsForLevel(
    String level,
    List<String> knownWords,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'knownByLevel': {level: knownWords},
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

  // 取得整份 knownByLevel 映射（e.g., { '1': [...], '2': [...] })
  static Future<Map<String, List<String>>> getKnownByLevel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    final Map<String, dynamic> byLevel =
        Map<String, dynamic>.from(data['knownByLevel'] ?? {});
    final result = byLevel.map((k, v) => MapEntry(k, List<String>.from(v ?? [])));

    // Legacy support: if no knownByLevel but legacy knownWords exists, expose under '_legacy'
    if (result.isEmpty && (data['knownWords'] is List) && (data['knownWords'] as List).isNotEmpty) {
      result['_legacy'] = List<String>.from(data['knownWords'] as List);
    }
    return result;
  }

  // 取得收藏清單
  static Future<List<String>> getFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final doc = await _db.collection('users').doc(user.uid).get();
    return List<String>.from((doc.data() ?? {})['favorites'] ?? []);
  }

  // 上傳測驗紀錄
  static Future<void> uploadQuizRecord(Map<String, dynamic> quizRecord) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('quizRecords')
        .add(quizRecord);
  }

  // 下載所有雲端資料（進度、收藏、測驗）
  static Future<Map<String, dynamic>?> downloadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    final quizSnapshots = await _db
        .collection('users')
        .doc(user.uid)
        .collection('quizRecords')
        .orderBy('timestamp', descending: true)
        .get();
    final data = doc.data() ?? {};
    return {
      'knownByLevel': Map<String, List<String>>.from(
        (data['knownByLevel'] ?? {}).map(
          (k, v) => MapEntry(k.toString(), List<String>.from(v ?? [])),
        ),
      ),
      'favorites': List<String>.from(data['favorites'] ?? []),
      'quizRecords': quizSnapshots.docs.map((d) => d.data()).toList(),
    };
  }
}
