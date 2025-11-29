import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendSummary {
  final String uid;
  final String displayName;
  final String? email;
  final int totalWordsLearned;
  final int currentStreak;
  final int totalStudyTime;
  final String? bio;

  FriendSummary({
    required this.uid,
    required this.displayName,
    this.email,
    this.totalWordsLearned = 0,
    this.currentStreak = 0,
    this.totalStudyTime = 0,
    this.bio,
  });
}

class FriendsService {
  static final _db = FirebaseFirestore.instance;

  static User? get _currentUser => FirebaseAuth.instance.currentUser;

  // 從整個 user 文件中安全地計算已學單字總數
  // 1. 優先使用 knownByLevel 各等級清單長度加總
  // 2. 若沒有 knownByLevel，再退回 learningStats.levelStats / totalWordsLearned
  static int _extractTotalWordsLearned(Map<String, dynamic> data) {
    // 優先使用 knownByLevel
    final knownByLevel = data['knownByLevel'];
    if (knownByLevel is Map<String, dynamic>) {
      int sum = 0;
      knownByLevel.forEach((level, list) {
        if (level == '_legacy') return; // 舊版合併鍵略過
        if (list is List) {
          sum += list.length;
        }
      });
      if (sum > 0) return sum;
    }

    // 再看 learningStats
    final stats = data['learningStats'] as Map<String, dynamic>?;
    if (stats != null) {
      final levelStats = stats['levelStats'];
      if (levelStats is Map<String, dynamic>) {
        int sum = 0;
        for (final entry in levelStats.values) {
          if (entry is Map<String, dynamic>) {
            final wl = entry['wordsLearned'];
            if (wl is int) {
              sum += wl;
            }
          }
        }
        if (sum > 0) return sum;
      }

      final total = stats['totalWordsLearned'];
      if (total is int) return total;
    }

    return 0;
  }

  static Future<List<String>> _getFriendUids() async {
    final user = _currentUser;
    if (user == null) return [];
    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    final List<dynamic> list = data['friends'] ?? [];
    return list.map((e) => e.toString()).toList();
  }

  static Future<List<FriendSummary>> getFriends() async {
    final user = _currentUser;
    if (user == null) return [];
    final friendUids = await _getFriendUids();
    if (friendUids.isEmpty) return [];

    final List<FriendSummary> result = [];
    // Firestore whereIn 最多 10 筆，分批查詢
    for (var i = 0; i < friendUids.length; i += 10) {
      final batch = friendUids.sublist(
          i, i + 10 > friendUids.length ? friendUids.length : i + 10);
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final stats = data['learningStats'] as Map<String, dynamic>?;
        final totalWords = _extractTotalWordsLearned(data);
        result.add(FriendSummary(
          uid: doc.id,
          displayName:
              (data['displayName'] as String?)?.trim().isNotEmpty == true
                  ? (data['displayName'] as String).trim()
                  : (data['email'] as String?) ?? '未命名',
          email: data['email'] as String?,
          totalWordsLearned: totalWords,
          currentStreak: (stats?['currentStreak'] as int?) ?? 0,
          totalStudyTime: (stats?['totalStudyTime'] as int?) ?? 0,
          bio: data['bio'] as String?,
        ));
      }
    }
    // 排行榜：先依已學單字數由多到少排序，再以名稱作為次要排序
    result.sort((a, b) {
      if (b.totalWordsLearned != a.totalWordsLearned) {
        return b.totalWordsLearned.compareTo(a.totalWordsLearned);
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return result;
  }

  static Future<List<FriendSummary>> searchUsers(String query) async {
    final user = _currentUser;
    if (user == null) return [];
    final q = query.trim();
    if (q.isEmpty) return [];

    final List<FriendSummary> result = [];
    final lowerQ = q.toLowerCase();

    // 改用更簡單可靠的方式：直接抓所有用戶（如果用戶量不大），然後在客戶端過濾
    // 這樣可以避免 Firestore 索引問題，並且支援部分匹配
    try {
      // 增加 limit 到 500，確保能搜尋到更多用戶
      final snap = await _db.collection('users').limit(500).get();

      print('[FriendsService] 搜尋關鍵字: "$q", 掃描到 ${snap.docs.length} 個用戶文件');

      // 特別檢查是否有 "deck" 相關的用戶
      bool foundDeck = false;

      for (final doc in snap.docs) {
        // 先檢查是否是自己（跳過）
        if (doc.id == user.uid) {
          print('[FriendsService] 跳過自己: uid=${doc.id}');
          continue;
        }

        final data = doc.data();
        final stats = data['learningStats'] as Map<String, dynamic>?;
        final rawName = (data['displayName'] as String?) ?? '';
        final rawEmail = (data['email'] as String?) ?? '';
        final name = rawName.trim();
        final email = rawEmail.trim();

        // 特別檢查 "deck" 相關的用戶
        if (name.toLowerCase().contains('deck') ||
            email.toLowerCase().contains('deck')) {
          print(
              '[FriendsService] 🔍 發現 "deck" 相關用戶: uid=${doc.id}, name="$name", email="$email", 當前搜尋關鍵字: "$q"');
          foundDeck = true;
        }

        // Debug: 列出所有掃描到的用戶（前 20 個）
        final index = snap.docs.indexOf(doc);
        if (index < 20) {
          print(
              '[FriendsService] 掃描用戶 #${index + 1}: uid=${doc.id.substring(0, 12)}..., name="$name", email="$email"');
        }

        final lowerName = name.toLowerCase();
        final lowerEmail = email.toLowerCase();

        // 匹配條件：暱稱或 email 完全匹配，或包含關鍵字（不分大小寫）
        final exactNameMatch = name.isNotEmpty && lowerName == lowerQ;
        final exactEmailMatch = email.isNotEmpty && lowerEmail == lowerQ;
        final containsName = name.isNotEmpty && lowerName.contains(lowerQ);
        final containsEmail = email.isNotEmpty && lowerEmail.contains(lowerQ);

        if (exactNameMatch ||
            exactEmailMatch ||
            containsName ||
            containsEmail) {
          print(
              '[FriendsService] ✓ 匹配到用戶: uid=${doc.id}, name="$name", email="$email"');
          final totalWords = _extractTotalWordsLearned(data);
          result.add(FriendSummary(
            uid: doc.id,
            displayName:
                name.isNotEmpty ? name : (email.isNotEmpty ? email : '未命名'),
            email: email.isNotEmpty ? email : null,
            totalWordsLearned: totalWords,
            currentStreak: (stats?['currentStreak'] as int?) ?? 0,
            totalStudyTime: (stats?['totalStudyTime'] as int?) ?? 0,
            bio: data['bio'] as String?,
          ));
        } else if (name.toLowerCase() == 'deck' && lowerQ == 'deck') {
          // 特別檢查：如果 name 是 "deck" 但沒匹配到，輸出詳細信息
          print(
              '[FriendsService] ⚠️ 發現 "deck" 但未匹配: uid=${doc.id}, name="$name" (length=${name.length}), 搜尋關鍵字="$q" (length=${q.length})');
          print(
              '[FriendsService]    lowerName="$lowerName", lowerQ="$lowerQ", 是否相等: ${lowerName == lowerQ}');
        }
      }

      if (!foundDeck && lowerQ.contains('deck')) {
        print(
            '[FriendsService] ⚠️ 警告：搜尋 "deck" 但掃描的 ${snap.docs.length} 個用戶中沒有找到包含 "deck" 的用戶');
      }
    } catch (e) {
      print('[FriendsService] 搜尋錯誤: $e');
    }

    // 按總學習單字數排序（排行榜用），同分再比名稱
    result.sort((a, b) {
      if (b.totalWordsLearned != a.totalWordsLearned) {
        return b.totalWordsLearned.compareTo(a.totalWordsLearned);
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    print('[FriendsService] 最終搜尋結果: ${result.length} 個');
    return result;
  }

  static Future<void> addFriend(String targetUid) async {
    final user = _currentUser;
    if (user == null || targetUid.isEmpty) return;
    if (targetUid == user.uid) return;
    await _db.collection('users').doc(user.uid).set(
      {
        'friends': FieldValue.arrayUnion([targetUid]),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> removeFriend(String targetUid) async {
    final user = _currentUser;
    if (user == null || targetUid.isEmpty) return;
    await _db.collection('users').doc(user.uid).set(
      {
        'friends': FieldValue.arrayRemove([targetUid]),
      },
      SetOptions(merge: true),
    );
  }
}
