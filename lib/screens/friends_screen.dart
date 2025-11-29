import 'package:flutter/material.dart';
import '../services/friends_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  bool _isLoading = true;
  List<FriendSummary> _friends = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    try {
      final list = await FriendsService.getFriends();
      if (!mounted) return;
      setState(() {
        _friends = list;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openSearch() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const FriendSearchScreen()),
    );
    if (added == true) {
      _loadFriends();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            onPressed: _openSearch,
            tooltip: '新增好友',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFriends,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_friends.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('目前尚未加入任何好友')),
                    ],
                  )
                : ListView.separated(
                    itemCount: _friends.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final f = _friends[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            '#${index + 1}',
                          ),
                        ),
                        title: Text(f.displayName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (f.bio != null && f.bio!.trim().isNotEmpty)
                              Text(f.bio!.trim())
                            else
                              const Text('尚未填寫個人簡介'),
                            Text(
                                '已學單字：${f.totalWordsLearned}，連續天數：${f.currentStreak}'),
                          ],
                        ),
                        // 排行榜與詳細資料之後再補
                      );
                    },
                  )),
      ),
    );
  }
}

class FriendSearchScreen extends StatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  State<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends State<FriendSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _hasSearched = false; // 是否已經執行過搜尋
  List<FriendSummary> _results = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      // 當輸入改變時，重置搜尋狀態
      if (_hasSearched && _searchController.text.trim().isEmpty) {
        setState(() {
          _hasSearched = false;
          _results = [];
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請輸入搜尋關鍵字')),
        );
      }
      return;
    }
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _results = [];
    });
    try {
      print('[FriendSearchScreen] 開始搜尋: "$query"');
      final list = await FriendsService.searchUsers(query);
      print('[FriendSearchScreen] 搜尋結果: ${list.length} 個');
      if (!mounted) return;
      setState(() {
        _results = list;
      });
      if (list.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('找不到符合 "$query" 的用戶')),
        );
      }
    } catch (e) {
      print('[FriendSearchScreen] 搜尋錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜尋時發生錯誤: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _addFriend(FriendSummary f) async {
    await FriendsService.addFriend(f.uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已加入 ${f.displayName} 為好友')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜尋好友'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: '輸入暱稱或 Email',
                      hintText: '例如: deck 或 tady0123@gmail.com',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _results = [];
                                  _hasSearched = false;
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    enabled: !_isSearching,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSearching ? null : _search,
                  icon: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: const Text('搜尋'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : (!_hasSearched
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('請輸入暱稱或 Email 搜尋好友'),
                            SizedBox(height: 8),
                            Text(
                              '例如: deck 或 tady0123@gmail.com',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_off,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('找不到符合條件的用戶'),
                                SizedBox(height: 8),
                                Text(
                                  '請確認輸入的暱稱或 Email 是否正確',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final f = _results[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    f.displayName.isNotEmpty
                                        ? f.displayName[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                                title: Text(f.displayName),
                                subtitle:
                                    f.email != null ? Text(f.email!) : null,
                                trailing: TextButton.icon(
                                  onPressed: () => _addFriend(f),
                                  icon: const Icon(Icons.person_add_alt_1,
                                      size: 18),
                                  label: const Text('加好友'),
                                ),
                              );
                            },
                          )),
          ),
        ],
      ),
    );
  }
}
