import 'package:flutter/material.dart';
import '../services/groups_service.dart';
import 'group_detail_screen.dart';
import 'create_group_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool _isLoading = true;
  List<GroupSummary> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final list = await GroupsService.getUserGroups();
      if (!mounted) return;
      setState(() {
        _groups = list;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openCreateGroup() async {
    final createdGroupId = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
    if (createdGroupId != null && createdGroupId.isNotEmpty) {
      // 背景更新群組列表，但不依賴列表來導航
      _loadGroups();
      _openGroupDetail(
        GroupSummary(
          id: createdGroupId,
          name: '群組',
          ownerUid: '',
          memberLimit: 0,
          isPublic: true,
          requireApproval: false,
          memberCount: 0,
        ),
      );
    }
  }

  Future<void> _openSearchGroups() async {
    final joinedGroupId = await showSearch<String?>(
      context: context,
      delegate: GroupSearchDelegate(),
    );
    if (joinedGroupId != null && joinedGroupId.isNotEmpty) {
      await _loadGroups();
      final group = _groups.firstWhere(
        (g) => g.id == joinedGroupId,
        orElse: () => _groups.first,
      );
      _openGroupDetail(group);
    }
  }

  void _openGroupDetail(GroupSummary group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GroupDetailScreen(groupId: group.id, groupName: group.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_groups.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('目前尚未加入任何群組')),
                    ],
                  )
                : ListView.separated(
                    itemCount: _groups.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final g = _groups[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColorLight,
                          child: const Icon(Icons.group, color: Colors.white),
                        ),
                        title: Text(g.name),
                        subtitle:
                            Text('成員 ${g.memberCount} / ${g.memberLimit}'),
                        onTap: () => _openGroupDetail(g),
                      );
                    },
                  )),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'searchGroup',
            onPressed: _openSearchGroups,
            icon: const Icon(Icons.search),
            label: const Text('加入群組'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'createGroup',
            onPressed: _openCreateGroup,
            icon: const Icon(Icons.group_add),
            label: const Text('建立群組'),
          ),
        ],
      ),
    );
  }
}

class GroupSearchDelegate extends SearchDelegate<String?> {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<GroupSummary>>(
      future: GroupsService.searchGroupsByName(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('找不到符合條件的群組'));
        }
        final results = snapshot.data!;
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final g = results[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColorLight,
                child: const Icon(Icons.group, color: Colors.white),
              ),
              title: Text(g.name),
              subtitle: Text('成員 ${g.memberCount} / ${g.memberLimit}'),
              trailing: TextButton(
                onPressed: () async {
                  if (g.isPublic && !g.requireApproval) {
                    await GroupsService.joinGroupDirect(g.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已加入群組 ${g.name}')),
                      );
                    }
                    close(context, g.id);
                  } else {
                    await GroupsService.requestToJoinGroup(g.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已送出加入申請給 ${g.name}')),
                      );
                    }
                    close(context, g.id);
                  }
                },
                child: Text(g.isPublic && !g.requireApproval ? '加入' : '申請加入'),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Center(
      child: Text(
        '輸入群組名稱進行搜尋',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
