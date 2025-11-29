import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupSummary {
  final String id;
  final String name;
  final String ownerUid;
  final int memberLimit;
  final bool isPublic;
  final bool requireApproval;
  final int memberCount;

  GroupSummary({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.memberLimit,
    required this.isPublic,
    required this.requireApproval,
    required this.memberCount,
  });
}

class GroupMemberProgress {
  final String uid;
  final String displayName;
  final int totalWordsLearned;
  final int currentStreak;

  GroupMemberProgress({
    required this.uid,
    required this.displayName,
    required this.totalWordsLearned,
    required this.currentStreak,
  });
}

class GroupMessage {
  final String id;
  final String senderUid;
  final String text;
  final DateTime createdAt;

  GroupMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.createdAt,
  });
}

class GroupsService {
  static final _db = FirebaseFirestore.instance;
  static User? get _currentUser => FirebaseAuth.instance.currentUser;

  static Future<String> createGroup({
    required String name,
    required int memberLimit,
    required bool isPublic,
    required bool requireApproval,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    final now = FieldValue.serverTimestamp();
    final ref = await _db.collection('groups').add({
      'name': name.trim(),
      'ownerUid': user.uid,
      'memberLimit': memberLimit,
      'isPublic': isPublic,
      'requireApproval': requireApproval,
      'deleted': false,
      'createdAt': now,
    });

    await _db
        .collection('groups')
        .doc(ref.id)
        .collection('members')
        .doc(user.uid)
        .set({
      'role': 'owner',
      'joinedAt': now,
    });

    // 將群組 ID 記錄到使用者文件，方便之後載入自己的群組
    await _db.collection('users').doc(user.uid).set({
      'groups': FieldValue.arrayUnion([ref.id]),
    }, SetOptions(merge: true));

    return ref.id;
  }

  static Future<List<GroupSummary>> getUserGroups() async {
    final user = _currentUser;
    if (user == null) return [];
    // 從使用者文件讀取自己參與的群組 ID 清單
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};
    final List<dynamic> rawList = data['groups'] ?? [];
    final List<String> groupIds =
        rawList.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();

    if (groupIds.isEmpty) return [];

    final List<GroupSummary> result = [];
    for (final gid in groupIds) {
      final gdoc = await _db.collection('groups').doc(gid).get();
      if (!gdoc.exists) continue;
      final gdata = gdoc.data()!;
      if ((gdata['deleted'] as bool?) == true) continue; // 已解散的群組不顯示
      final membersSnap = await gdoc.reference.collection('members').get();
      result.add(GroupSummary(
        id: gdoc.id,
        name: (gdata['name'] as String?) ?? '未命名群組',
        ownerUid: (gdata['ownerUid'] as String?) ?? '',
        memberLimit: (gdata['memberLimit'] as int?) ?? 50,
        isPublic: (gdata['isPublic'] as bool?) ?? true,
        requireApproval: (gdata['requireApproval'] as bool?) ?? false,
        memberCount: membersSnap.size,
      ));
    }

    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  static Future<List<GroupSummary>> searchGroupsByName(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return [];

    final snap = await _db
        .collection('groups')
        .where('isPublic', isEqualTo: true)
        .limit(100)
        .get();

    final lower = q.toLowerCase();
    final List<GroupSummary> result = [];
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = (data['name'] as String?) ?? '';
      if (!name.toLowerCase().contains(lower)) continue;
      final membersSnap =
          await doc.reference.collection('members').limit(200).get();
      result.add(GroupSummary(
        id: doc.id,
        name: name,
        ownerUid: (data['ownerUid'] as String?) ?? '',
        memberLimit: (data['memberLimit'] as int?) ?? 50,
        isPublic: (data['isPublic'] as bool?) ?? true,
        requireApproval: (data['requireApproval'] as bool?) ?? false,
        memberCount: membersSnap.size,
      ));
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  static Future<void> joinGroupDirect(String groupId) async {
    final user = _currentUser;
    if (user == null) return;
    final now = FieldValue.serverTimestamp();
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(user.uid)
        .set({
      'role': 'member',
      'joinedAt': now,
    }, SetOptions(merge: true));

    // 把群組 ID 加入使用者文件
    await _db.collection('users').doc(user.uid).set({
      'groups': FieldValue.arrayUnion([groupId]),
    }, SetOptions(merge: true));
  }

  static Future<void> requestToJoinGroup(String groupId) async {
    final user = _currentUser;
    if (user == null) return;
    final now = FieldValue.serverTimestamp();
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('joinRequests')
        .doc(user.uid)
        .set({
      'requestedAt': now,
      'status': 'pending',
    }, SetOptions(merge: true));
  }

  static Future<void> leaveGroup(String groupId) async {
    final user = _currentUser;
    if (user == null) return;

    // 從 members 子集合移除
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(user.uid)
        .delete();

    // 從使用者文件的 groups 陣列移除
    await _db.collection('users').doc(user.uid).set({
      'groups': FieldValue.arrayRemove([groupId]),
    }, SetOptions(merge: true));
  }

  static Future<void> disbandGroup(String groupId) async {
    final user = _currentUser;
    if (user == null) return;

    final doc = await _db.collection('groups').doc(groupId).get();
    final data = doc.data();
    if (data == null) return;
    if (data['ownerUid'] != user.uid) {
      throw Exception('只有群組擁有者可以解散群組');
    }

    // 採用 soft delete：標記 deleted=true，並從 owner 的 groups 陣列移除
    await _db.collection('groups').doc(groupId).set({
      'deleted': true,
    }, SetOptions(merge: true));

    await _db.collection('users').doc(user.uid).set({
      'groups': FieldValue.arrayRemove([groupId]),
    }, SetOptions(merge: true));
  }

  static Future<String?> getGroupOwnerUid(String groupId) async {
    final doc = await _db.collection('groups').doc(groupId).get();
    final data = doc.data();
    return data?['ownerUid'] as String?;
  }

  static Stream<List<GroupMessage>> streamGroupMessages(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              final ts = data['createdAt'];
              DateTime created;
              if (ts is Timestamp) {
                created = ts.toDate();
              } else {
                created = DateTime.now();
              }
              return GroupMessage(
                id: d.id,
                senderUid: (data['senderUid'] as String?) ?? '',
                text: (data['text'] as String?) ?? '',
                createdAt: created,
              );
            }).toList());
  }

  static Future<void> sendMessage({
    required String groupId,
    required String text,
  }) async {
    final user = _currentUser;
    if (user == null) return;
    final now = FieldValue.serverTimestamp();
    await _db.collection('groups').doc(groupId).collection('messages').add({
      'senderUid': user.uid,
      'text': text.trim(),
      'createdAt': now,
    });
  }
}
