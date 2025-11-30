import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/groups_service.dart';
import '../services/online_study_time_store.dart';
import '../utils/time_format.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;
  String? _ownerUid;
  String? _localNickname;
  bool _savingNickname = false;

  // 從 user 文件中計算已學單字總數的 helper（邏輯與 FriendsService._extractTotalWordsLearned 一致）
  int _extractTotalWordsLearned(Map<String, dynamic> data) {
    final knownByLevel = data['knownByLevel'];
    if (knownByLevel is Map<String, dynamic>) {
      int sum = 0;
      knownByLevel.forEach((level, list) {
        if (level == '_legacy') return;
        if (list is List) {
          sum += list.length;
        }
      });
      if (sum > 0) return sum;
    }

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

  // 從 learningStats.levelStats 取得最近學習的等級（與 FriendsService 相同邏輯）
  String? _extractCurrentLevel(Map<String, dynamic> data) {
    final stats = data['learningStats'] as Map<String, dynamic>?;
    if (stats == null) return null;
    final levelStats = stats['levelStats'];
    if (levelStats is! Map<String, dynamic>) return null;

    String? latestLevel;
    DateTime? latestTime;
    levelStats.forEach((level, value) {
      if (value is Map<String, dynamic>) {
        final ts = value['lastStudied'];
        DateTime? t;
        if (ts is Timestamp) {
          t = ts.toDate();
        } else if (ts is String) {
          try {
            t = DateTime.parse(ts);
          } catch (_) {}
        }
        if (t != null) {
          if (latestTime == null || t.isAfter(latestTime!)) {
            latestTime = t;
            latestLevel = level.toString();
          }
        }
      }
    });
    return latestLevel;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGroupMeta();
    _loadLocalNickname();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await GroupsService.sendMessage(groupId: widget.groupId, text: text);
      _messageController.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _loadGroupMeta() async {
    final doc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .get();
    final data = doc.data() ?? {};
    setState(() {
      _ownerUid = data['ownerUid'] as String?;
    });
  }

  Future<void> _loadLocalNickname() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final memberDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .doc(user.uid)
        .get();
    final data = memberDoc.data();
    if (data != null && mounted) {
      setState(() {
        _localNickname = data['nickname'] as String?;
      });
    }
  }

  Future<void> _saveLocalNickname() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _savingNickname = true);
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .doc(user.uid)
          .set({
        'nickname': _localNickname?.trim() ?? '',
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存群組暱稱')),
      );
    } finally {
      if (mounted) setState(() => _savingNickname = false);
    }
  }

  Future<void> _leaveGroup() async {
    await GroupsService.leaveGroup(widget.groupId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _disbandGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解散群組'),
        content: const Text('解散後群組將無法復原，確定要解散嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('解散', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await GroupsService.disbandGroup(widget.groupId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '成員進度'),
            Tab(text: '聊天'),
            Tab(text: '設定'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMembersTab(),
          _buildChatTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('目前沒有成員資料'));
        }
        final memberDocs = snapshot.data!.docs;
        return ListView.separated(
          itemCount: memberDocs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final m = memberDocs[index];
            final uid = m.id;
            final memberData = m.data();
            final memberNickname = (memberData['nickname'] as String?)?.trim();
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future:
                  FirebaseFirestore.instance.collection('users').doc(uid).get(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const ListTile(
                    title: Text('載入中...'),
                  );
                }
                final data = snap.data!.data() ?? {};
                final baseName = (data['displayName'] as String?) ??
                    (data['email'] as String?) ??
                    '未命名';
                final displayName =
                    (memberNickname != null && memberNickname.isNotEmpty)
                        ? memberNickname
                        : baseName;

                final totalWordsLearned = _extractTotalWordsLearned(data);
                final stats = data['learningStats'] as Map<String, dynamic>?;
                final currentStreak = (stats?['currentStreak'] as int?) ?? 0;
                final currentLevel = _extractCurrentLevel(data);
                final todaySeconds = (stats?['todayStudySeconds'] as int?) ?? 0;
                final isOnline = (data['isOnline'] as bool?) ?? false;

                // 同步更新共用的線上學習時間 store，讓群組成員也共用同一份秒數狀態
                OnlineStudyTimeStore.instance.updateFromServer(
                  uid: uid,
                  baseSeconds: todaySeconds,
                  isOnline: isOnline,
                );
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(displayName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('已學單字：$totalWordsLearned，連續天數：$currentStreak'),
                      const SizedBox(height: 2),
                      _MemberStudyTimeRow(
                        uid: uid,
                        currentLevel: currentLevel,
                        initialSeconds: todaySeconds,
                        isOnline: isOnline,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatTab() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<GroupMessage>>(
            stream: GroupsService.streamGroupMessages(widget.groupId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return const Center(child: Text('還沒有訊息，來說點什麼吧！'));
              }
              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final m = messages[index];
                  final isMe = m.senderUid == currentUid;
                  // 先讀取群組成員資料（拿到 nickname），再讀取 user 資料取得 displayName/email
                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('groups')
                        .doc(widget.groupId)
                        .collection('members')
                        .doc(m.senderUid)
                        .get(),
                    builder: (context, memberSnap) {
                      String? nickname;
                      if (memberSnap.hasData &&
                          memberSnap.data!.data() != null) {
                        final data = memberSnap.data!.data()!;
                        nickname = (data['nickname'] as String?)?.trim();
                      }

                      return FutureBuilder<
                          DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(m.senderUid)
                            .get(),
                        builder: (context, userSnap) {
                          String baseName = '成員';
                          if (userSnap.hasData &&
                              userSnap.data!.data() != null) {
                            final u = userSnap.data!.data()!;
                            baseName = (u['displayName'] as String?) ??
                                (u['email'] as String?) ??
                                '成員';
                          }
                          final senderName =
                              (nickname != null && nickname.isNotEmpty)
                                  ? nickname
                                  : baseName;

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: Text(
                                    senderName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? const Color(0xFF06C755) // LINE 綠色風格
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(16).copyWith(
                                      bottomLeft:
                                          Radius.circular(isMe ? 16 : 2),
                                      bottomRight:
                                          Radius.circular(isMe ? 2 : 16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    m.text,
                                    style: TextStyle(
                                      color:
                                          isMe ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '輸入訊息',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 10.0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  color: const Color(0xFF06C755),
                  onPressed: _sending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = user != null && _ownerUid == user.uid;
    final controller = TextEditingController(text: _localNickname ?? '');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('群組暱稱（所有成員可見）'),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '在這個群組中顯示給自己的名稱',
            ),
            onChanged: (v) => _localNickname = v,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _savingNickname ? null : _saveLocalNickname,
              child: _savingNickname
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('儲存暱稱'),
            ),
          ),
          const Divider(height: 32),
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('解散群組', style: TextStyle(color: Colors.red)),
              onTap: _disbandGroup,
            )
          else
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('退出群組', style: TextStyle(color: Colors.red)),
              onTap: _leaveGroup,
            ),
        ],
      ),
    );
  }
}

class _MemberStudyTimeRow extends StatelessWidget {
  final String uid;
  final String? currentLevel;
  final int initialSeconds;
  final bool isOnline;

  const _MemberStudyTimeRow({
    required this.uid,
    required this.currentLevel,
    required this.initialSeconds,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final store = OnlineStudyTimeStore.instance;
    return ValueListenableBuilder<int>(
      valueListenable: store.listenableFor(uid),
      builder: (context, seconds, _) {
        final displaySeconds = seconds > 0 ? seconds : initialSeconds;
        final online = store.isOnline(uid) || isOnline;
        return Row(
          children: [
            Text(
              currentLevel != null ? '等級 $currentLevel' : '等級 -',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 12),
            Text(
              formatSecondsToHms(displaySeconds),
              style: TextStyle(
                fontSize: 12,
                color: online ? Colors.green : Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }
}
