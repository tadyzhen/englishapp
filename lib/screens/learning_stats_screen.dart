import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/learning_stats.dart';
import '../services/learning_stats_service.dart';
import '../services/online_study_time_store.dart';
import '../utils/time_format.dart';

class LearningStatsScreen extends StatefulWidget {
  const LearningStatsScreen({super.key});

  @override
  State<LearningStatsScreen> createState() => _LearningStatsScreenState();
}

class _LearningStatsScreenState extends State<LearningStatsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  LearningStats? _stats;
  Map<String, dynamic>? _trends;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStats();

    // 監聽統計資料變更，自動刷新
    LearningStatsService.statsVersion.addListener(_loadStats);
  }

  @override
  void dispose() {
    LearningStatsService.statsVersion.removeListener(_loadStats);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
      final stats = await LearningStatsService.getLearningStats();
      final trends = await LearningStatsService.getLearningTrends();

      setState(() {
        _stats = stats;
        _trends = trends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入統計數據失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('學習統計')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_stats == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('學習統計')),
        body: const Center(
          child: Text('無法載入統計數據'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('學習統計'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: '重新整理',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '總覽', icon: Icon(Icons.dashboard)),
            Tab(text: '進度', icon: Icon(Icons.trending_up)),
            Tab(text: '成就', icon: Icon(Icons.emoji_events)),
            Tab(text: '歷史', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildProgressTab(),
          _buildAchievementsTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(),
          const SizedBox(height: 20), // 減少間距
          _buildStreakCard(),
          const SizedBox(height: 20), // 減少間距
          _buildLevelProgressCard(),
          const SizedBox(height: 20), // 減少間距
          _buildQuizStatsCard(),
          const SizedBox(height: 16), // 底部額外間距
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3, // 增加高度比例
      children: [
        _buildStatCard(
          '今日學習單字',
          '${_todayWordsLearned()}',
          Icons.today,
          Colors.teal,
        ),
        _buildTodayStudyTimeCard(),
        _buildStatCard(
          '總學習單字',
          '${_stats!.totalWordsLearned}',
          Icons.book,
          Colors.blue,
        ),
        _buildStatCard(
          '總學習時間',
          formatSecondsToHms(_stats!.totalStudyTime * 60),
          Icons.access_time,
          Colors.green,
        ),
        _buildStatCard(
          '連續學習',
          '${_stats!.currentStreak} 天',
          Icons.local_fire_department,
          Colors.orange,
        ),
        _buildStatCard(
          '測驗次數',
          '${_stats!.totalQuizzesTaken}',
          Icons.quiz,
          Colors.purple,
        ),
      ],
    );
  }

  int _todayWordsLearned() {
    final key = _dateKey(DateTime.now());
    return _stats!.dailyWordsLearned[key] ?? 0;
  }

  int _todayStudySeconds() {
    final key = _dateKey(DateTime.now());
    final minutes = _stats!.dailyStudyTime[key] ?? 0;
    return minutes * 60;
  }

  Widget _buildTodayStudyTimeCard() {
    final fallbackSeconds = _todayStudySeconds();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildStatCard(
        '今日學習時間',
        formatSecondsToHms(fallbackSeconds),
        Icons.timer,
        Colors.indigo,
      );
    }

    final store = OnlineStudyTimeStore.instance;

    return ValueListenableBuilder<int>(
      valueListenable: store.listenableFor(user.uid),
      builder: (context, seconds, _) {
        final displaySeconds = seconds > 0 ? seconds : fallbackSeconds;
        return _buildStatCard(
          '今日學習時間',
          formatSecondsToHms(displaySeconds),
          Icons.timer,
          Colors.indigo,
        );
      },
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12), // 減少內邊距
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // 確保最小尺寸
          children: [
            Icon(icon, size: 28, color: color), // 稍微減小圖標尺寸
            const SizedBox(height: 6), // 減少間距
            Flexible(
              // 使用 Flexible 防止溢出
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18, // 稍微減小字體
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4), // 減少間距
            Flexible(
              // 使用 Flexible 防止溢出
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11, // 稍微減小字體
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  '學習連續性',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${_stats!.currentStreak}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const Text('目前連續'),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${_stats!.longestStreak}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const Text('最長記錄'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelProgressCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '等級進度',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._stats!.levelStats.values
                .map((levelStats) => _buildLevelProgressItem(levelStats))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelProgressItem(LevelStats levelStats) {
    final total = levelStats.totalWords > 0 ? levelStats.totalWords : 1;
    final clampedLearned = levelStats.wordsLearned.clamp(0, total);
    final rawProgress = levelStats.totalWords > 0
        ? clampedLearned / levelStats.totalWords
        : 0.0;
    final clampedProgress = rawProgress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('等級 ${levelStats.level}'),
              Text('$clampedLearned/${levelStats.totalWords}'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: clampedProgress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 4),
          Text(
            '${(clampedProgress * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizStatsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  '測驗統計',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${_stats!.totalQuizzesTaken}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    const Text('總測驗次數'),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${(_stats!.averageQuizScore * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Text('平均準確率'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTab() {
    if (_trends == null) {
      return const Center(child: Text('無法載入進度數據'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDailyStudyChart(),
          const SizedBox(height: 24),
          _buildWeeklyProgressChart(),
          const SizedBox(height: 24),
          _buildLevelComparisonChart(),
        ],
      ),
    );
  }

  Widget _buildDailyStudyChart() {
    final dailyData = _trends!['dailyStudyTime'] as Map<String, int>;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '過去7天學習時間',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildBarChart(dailyData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyProgressChart() {
    final weeklyData = _trends!['weeklyProgress'] as Map<String, int>;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '過去4週學習進度',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildBarChart(weeklyData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, int> data) {
    final values = data.values.toList();
    final maxValue =
        values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.entries.map((entry) {
        final height = maxValue > 0 ? (entry.value / maxValue) * 150 : 0.0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 30,
              height: height,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.key.split('-').last, // 只顯示日期部分
              style: const TextStyle(fontSize: 10),
            ),
            Text(
              '${entry.value}',
              style: const TextStyle(fontSize: 8),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildLevelComparisonChart() {
    final levelData = _trends!['levelProgress'] as Map<String, LevelStats>;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '各等級學習進度',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...levelData.values
                .map((levelStats) => _buildLevelProgressItem(levelStats))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAchievementSummary(),
          const SizedBox(height: 24),
          _buildAchievementList(),
        ],
      ),
    );
  }

  Widget _buildAchievementSummary() {
    final unlockedCount =
        _stats!.achievements.where((a) => a.isUnlocked).length;
    final totalCount = _stats!.achievements.length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$unlockedCount',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const Text('已解鎖成就'),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '$totalCount',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const Text('總成就數'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: totalCount > 0 ? unlockedCount / totalCount : 0,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementList() {
    if (_stats!.achievements.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('還沒有成就，繼續學習吧！'),
          ),
        ),
      );
    }

    return Column(
      children: _stats!.achievements
          .map((achievement) => _buildAchievementItem(achievement))
          .toList(),
    );
  }

  Widget _buildAchievementItem(Achievement achievement) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: achievement.isUnlocked ? Colors.amber : Colors.grey,
          child: Text(
            achievement.icon,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          achievement.title,
          style: TextStyle(
            fontWeight:
                achievement.isUnlocked ? FontWeight.bold : FontWeight.normal,
            color: achievement.isUnlocked ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(achievement.description),
            if (!achievement.isUnlocked) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: achievement.progressPercentage,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              Text(
                '${achievement.progress}/${achievement.target}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
        trailing: achievement.isUnlocked
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.lock, color: Colors.grey),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadQuizHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final history = snapshot.data!;
        if (history.isEmpty) {
          return const Center(child: Text('尚無測驗紀錄'));
        }
        return ListView.separated(
          itemCount: history.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, idx) {
            final item = history[idx];
            final type = item['type'] ?? '';
            final level = item['level'] ?? '-';
            final score = item['score'] ?? 0;
            final total = item['questionCount'] ?? 0;
            final startedAt =
                DateTime.tryParse(item['startedAt'] ?? '') ?? DateTime.now();
            final duration = (item['durationSeconds'] ?? 0) as int;
            final wrongWords =
                (item['wrongWords'] as List<dynamic>?)?.cast<String>() ??
                    const <String>[];

            return ExpansionTile(
              leading: const Icon(Icons.quiz),
              title: Text('${_formatQuizType(type)}  等級: ${level ?? '全部'}'),
              subtitle: Text(
                '${_formatDateTime(startedAt)}  |  成績: $score/$total  |  ${duration}s',
              ),
              children: [
                if (wrongWords.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      '此紀錄沒有錯題資料',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                else
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '錯題單字：',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: wrongWords
                              .map((w) => Chip(
                                    label: Text(w),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadQuizHistory() async {
    try {
      final data = await LearningStatsService.downloadFullUserData();
      final cloud = (data?['quizRecords'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final local = await LearningStatsService.loadLocalQuizHistory();

      final all = <Map<String, dynamic>>[...cloud, ...local].where((m) {
        final wrong = m['wrongWords'];
        if (wrong is List) {
          return wrong.isNotEmpty;
        }
        return false;
      }).toList();
      all.sort((a, b) {
        final ta = (a['timestamp'] ?? '') as String;
        final tb = (b['timestamp'] ?? '') as String;
        return tb.compareTo(ta);
      });
      return all.take(10).toList();
    } catch (_) {
      return [];
    }
  }

  String _formatQuizType(String type) {
    switch (type) {
      case 'ch2en':
        return '中譯英';
      case 'en2ch':
        return '英譯中';
      case 'listening':
        return '聽力測驗';
      case 'spelling':
        return '拼字測驗';
      case 'fillin':
        return '填空測驗';
      default:
        return type;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
