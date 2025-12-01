import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/learning_stats.dart';
import '../firestore_sync.dart';
// import 'package:flutter/material.dart';

class LearningStatsService {
  static const String _statsKey = 'learning_stats';
  static const String _quizHistoryKey = 'quiz_history';
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final ValueNotifier<int> statsVersion = ValueNotifier<int>(0);

  // 獲取學習統計數據
  static Future<LearningStats> getLearningStats() async {
    try {
      // 先從本地獲取
      final prefs = await SharedPreferences.getInstance();
      final localStats = prefs.getString(_statsKey);

      if (localStats != null) {
        var stats = await _ensureAchievementsCatalog(
            LearningStats.fromJson(json.decode(localStats)));
        stats = await _reconcileWithCloudKnownWords(stats);

        // 嘗試從雲端同步
        await _syncFromCloud();

        // 重新從本地讀取（可能已被雲端數據更新）
        final updatedStats = prefs.getString(_statsKey);
        if (updatedStats != null) {
          var refreshed = await _ensureAchievementsCatalog(
              LearningStats.fromJson(json.decode(updatedStats)));
          refreshed = await _reconcileWithCloudKnownWords(refreshed);
          return refreshed;
        }

        return stats;
      }

      // 如果本地沒有數據，嘗試從雲端獲取
      var cloud = await _loadFromCloud();
      cloud = await _ensureAchievementsCatalog(cloud);
      cloud = await _reconcileWithCloudKnownWords(cloud);
      return cloud;
    } catch (e) {
      print('Error loading learning stats: $e');
      return LearningStats.empty();
    }
  }

  // 保存學習統計數據
  static Future<void> saveLearningStats(LearningStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statsKey, json.encode(stats.toJson()));

      // 同步到雲端
      await _syncToCloud(stats);

      // 通知觀察者有更新
      try {
        statsVersion.value = statsVersion.value + 1;
      } catch (_) {}
    } catch (e) {
      print('Error saving learning stats: $e');
    }
  }

  // 更新學習進度
  static Future<void> updateLearningProgress({
    required String level,
    required int wordsLearned,
    required int studyTimeMinutes,
    required int correctAnswers,
    required int totalAnswers,
  }) async {
    try {
      final stats = await getLearningStats();
      final now = DateTime.now();

      // 更新總體統計
      final updatedStats = stats.copyWith(
        totalWordsLearned: stats.totalWordsLearned + wordsLearned,
        totalStudyTime: stats.totalStudyTime + studyTimeMinutes,
        lastStudyDate: now,
        totalFavorites: await _getTotalFavorites(),
      );

      // 更新等級統計
      final levelStats = updatedStats.levelStats[level] ??
          LevelStats(
            level: level,
            wordsLearned: 0,
            totalWords: await _getTotalWordsForLevel(level),
            studyTime: 0,
            accuracy: 0.0,
            lastStudied: now,
          );

      final updatedLevelStats = levelStats.copyWith(
        wordsLearned: levelStats.wordsLearned + wordsLearned,
        studyTime: levelStats.studyTime + studyTimeMinutes,
        accuracy: _calculateAccuracy(levelStats, correctAnswers, totalAnswers),
        lastStudied: now,
      );

      final newLevelStats =
          Map<String, LevelStats>.from(updatedStats.levelStats);
      newLevelStats[level] = updatedLevelStats;

      // 更新連續學習天數
      final streak = _calculateStreak(stats, now);
      final longestStreak =
          streak > stats.longestStreak ? streak : stats.longestStreak;

      // 更新每日學習時間
      final dailyKey = _getDateKey(now);
      final dailyStudyTime = Map<String, int>.from(updatedStats.dailyStudyTime);
      dailyStudyTime[dailyKey] =
          (dailyStudyTime[dailyKey] ?? 0) + studyTimeMinutes;

      // 更新每週進度
      final weeklyKey = _getWeekKey(now);
      final weeklyProgress = Map<String, int>.from(updatedStats.weeklyProgress);
      weeklyProgress[weeklyKey] =
          (weeklyProgress[weeklyKey] ?? 0) + wordsLearned;

      // 更新每日學到的單字數
      final dailyWords = Map<String, int>.from(updatedStats.dailyWordsLearned);
      dailyWords[dailyKey] = (dailyWords[dailyKey] ?? 0) + wordsLearned;

      final finalStats = updatedStats.copyWith(
        currentStreak: streak,
        longestStreak: longestStreak,
        levelStats: newLevelStats,
        dailyStudyTime: dailyStudyTime,
        weeklyProgress: weeklyProgress,
        dailyWordsLearned: dailyWords,
      );

      // 構建成就清單（包含未解鎖進度）並儲存
      final withAchievements = await _buildAchievementsWithProgress(finalStats);
      await saveLearningStats(withAchievements);

      // 重新安排提醒（若設定了每日目標與提醒時間）
      try {
        // We don't have BuildContext here; caller should trigger reschedule when possible.
      } catch (_) {}
    } catch (e) {
      print('Error updating learning progress: $e');
    }
  }

  // 更新測驗結果
  static Future<void> updateQuizResult({
    required String level,
    required int score,
    required int totalQuestions,
    required int studyTimeMinutes,
  }) async {
    try {
      final stats = await getLearningStats();
      final accuracy = totalQuestions > 0 ? score / totalQuestions : 0.0;

      // 更新測驗統計
      final newAverageScore = _calculateAverageScore(
        stats.averageQuizScore,
        stats.totalQuizzesTaken,
        accuracy,
      );

      final updatedStats = stats.copyWith(
        totalQuizzesTaken: stats.totalQuizzesTaken + 1,
        averageQuizScore: newAverageScore,
        totalStudyTime: stats.totalStudyTime + studyTimeMinutes,
      );

      // 更新等級準確率
      final levelStats = updatedStats.levelStats[level];
      if (levelStats != null) {
        final updatedLevelStats = levelStats.copyWith(
          accuracy: _calculateAccuracy(levelStats, score, totalQuestions),
        );

        final newLevelStats =
            Map<String, LevelStats>.from(updatedStats.levelStats);
        newLevelStats[level] = updatedLevelStats;

        final finalStats = updatedStats.copyWith(levelStats: newLevelStats);
        await saveLearningStats(finalStats);
      } else {
        await saveLearningStats(updatedStats);
      }
    } catch (e) {
      print('Error updating quiz result: $e');
    }
  }

  // 記錄學習會話
  static Future<void> recordStudySession(StudySession session) async {
    try {
      await updateLearningProgress(
        level: session.level,
        wordsLearned: session.wordsStudied,
        studyTimeMinutes: session.studyTime,
        correctAnswers: session.correctAnswers,
        totalAnswers: session.totalAnswers,
      );
    } catch (e) {
      print('Error recording study session: $e');
    }
  }

  // 獲取學習趨勢數據
  static Future<Map<String, dynamic>> getLearningTrends() async {
    try {
      final stats = await getLearningStats();
      final now = DateTime.now();

      // 過去7天的學習時間
      final last7Days = <String, int>{};
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = _getDateKey(date);
        last7Days[key] = stats.dailyStudyTime[key] ?? 0;
      }

      // 過去4週的學習進度
      final last4Weeks = <String, int>{};
      for (int i = 3; i >= 0; i--) {
        final week = now.subtract(Duration(days: i * 7));
        final key = _getWeekKey(week);
        last4Weeks[key] = stats.weeklyProgress[key] ?? 0;
      }

      return {
        'dailyStudyTime': last7Days,
        'weeklyProgress': last4Weeks,
        'levelProgress': stats.levelStats,
        'totalStats': {
          'totalWordsLearned': stats.totalWordsLearned,
          'totalStudyTime': stats.totalStudyTime,
          'currentStreak': stats.currentStreak,
          'longestStreak': stats.longestStreak,
          'totalQuizzesTaken': stats.totalQuizzesTaken,
          'averageQuizScore': stats.averageQuizScore,
        },
      };
    } catch (e) {
      print('Error getting learning trends: $e');
      return {};
    }
  }

  // 提供統一方法，給統計頁讀取完整使用者資料（含測驗紀錄）
  static Future<Map<String, dynamic>?> downloadFullUserData() async {
    try {
      return await FirestoreSync.downloadUserData();
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveQuizRecordLocally(
      Map<String, dynamic> quizRecord) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_quizHistoryKey) ?? <String>[];
      list.add(json.encode(quizRecord));
      while (list.length > 50) {
        list.removeAt(0);
      }
      await prefs.setStringList(_quizHistoryKey, list);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> loadLocalQuizHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_quizHistoryKey) ?? <String>[];
      return list
          .map((s) {
            try {
              return Map<String, dynamic>.from(json.decode(s));
            } catch (_) {
              return <String, dynamic>{};
            }
          })
          .where((m) => m.isNotEmpty)
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  // 私有方法
  static Future<void> _syncFromCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data();

      if (data != null && data['learningStats'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_statsKey, json.encode(data['learningStats']));
      }
    } catch (e) {
      print('Error syncing from cloud: $e');
    }
  }

  static Future<void> _syncToCloud(LearningStats stats) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _db.collection('users').doc(user.uid).set({
        'learningStats': stats.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error syncing to cloud: $e');
    }
  }

  static Future<LearningStats> _loadFromCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return LearningStats.empty();

      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data();

      if (data != null && data['learningStats'] != null) {
        final stats = LearningStats.fromJson(data['learningStats']);
        final ensured = await _ensureAchievementsCatalog(stats);
        final reconciled = await _reconcileWithCloudKnownWords(ensured);
        await saveLearningStats(reconciled);
        return reconciled;
      }

      return LearningStats.empty();
    } catch (e) {
      print('Error loading from cloud: $e');
      return LearningStats.empty();
    }
  }

  // 將雲端 knownByLevel 的已學單字數整合進本地統計，避免只計入登入後的新學單字
  static Future<LearningStats> _reconcileWithCloudKnownWords(
      LearningStats stats) async {
    try {
      final knownByLevel = await FirestoreSync.getKnownByLevel();
      // 從 assets 計算各等級總單字數（與主畫面一致）
      final levelTotals = await _loadLevelTotalsFromAssets();

      // 計算各等級的雲端學習數
      final Map<String, int> cloudCounts = {};
      knownByLevel.forEach((level, list) {
        if (level == '_legacy') return; // 跳過舊版合併鍵
        cloudCounts[level] = list.length;
      });

      // 從本機 SharedPreferences 讀取 known_<level>，若存在則優先採用本機，
      // 這樣在主畫面重置進度後，統計頁也會跟著同步（不會被舊的雲端數字蓋回去）。
      final localCounts = await _loadLocalKnownCounts();

      if (cloudCounts.isEmpty && localCounts.isEmpty) return stats;

      // 更新等級統計：
      // - wordsLearned：優先使用本機 known_<level> 的數量，沒有本機時才用雲端 knownByLevel
      // - totalWords：對齊 assets/words.json 的實際單字數，避免使用預設 1000
      final newLevelStats = Map<String, LevelStats>.from(stats.levelStats);
      int cloudTotal = 0;
      final allLevels = <String>{...cloudCounts.keys, ...localCounts.keys};
      for (final levelKey in allLevels) {
        final cloudCount = cloudCounts[levelKey] ?? 0;
        final localCount = localCounts[levelKey];
        final effectiveCount = localCount ?? cloudCount;
        cloudTotal += effectiveCount;
        final existing = newLevelStats[levelKey] ??
            LevelStats(
              level: levelKey,
              wordsLearned: 0,
              totalWords: levelTotals[levelKey] ?? 0,
              studyTime: 0,
              accuracy: 0.0,
              lastStudied: stats.lastStudyDate,
            );
        newLevelStats[levelKey] = existing.copyWith(
          wordsLearned: effectiveCount,
          totalWords: levelTotals[levelKey] ?? existing.totalWords,
        );
      }

      // 若雲端總數較大，提升 totalWordsLearned
      final adjustedTotal = cloudTotal > stats.totalWordsLearned
          ? cloudTotal
          : stats.totalWordsLearned;

      return stats.copyWith(
        totalWordsLearned: adjustedTotal,
        levelStats: newLevelStats,
      );
    } catch (e) {
      return stats;
    }
  }

  static Future<int> _getTotalWordsForLevel(String level) async {
    final totals = await _loadLevelTotalsFromAssets();
    return totals[level] ?? 0;
  }

  // 從本機 SharedPreferences 讀取各等級已學單字數（known_<level>），
  // 供統計頁與主畫面使用相同來源的進度資料。
  static Future<Map<String, int>> _loadLocalKnownCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, int> result = {};
    for (final lv in ['1', '2', '3', '4', '5', '6']) {
      final list = prefs.getStringList('known_$lv') ?? <String>[];
      result[lv] = list.length;
    }
    return result;
  }

  // 快取各等級總單字數，避免重複讀取 assets
  static Map<String, int>? _levelTotalsCache;

  static Future<Map<String, int>> _loadLevelTotalsFromAssets() async {
    if (_levelTotalsCache != null) return _levelTotalsCache!;
    try {
      final data = await rootBundle.loadString('assets/words.json');
      final List<dynamic> jsonResult = json.decode(data);
      final Map<String, int> totals = {};
      for (final item in jsonResult) {
        final map = item as Map<String, dynamic>;
        final level = map['level']?.toString();
        if (level == null) continue;
        totals[level] = (totals[level] ?? 0) + 1;
      }
      _levelTotalsCache = totals;
      return totals;
    } catch (_) {
      // 發生錯誤時回傳空 map，避免整體失敗
      _levelTotalsCache = {};
      return _levelTotalsCache!;
    }
  }

  // ===== Spaced Repetition (SRS) lightweight helpers =====
  // We store per-word SRS data in SharedPreferences as json map per level
  static const String _srsPrefix = 'srs_';

  static Future<Map<String, dynamic>> getSrsDataForLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_srsPrefix$level');
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(json.decode(raw));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveSrsDataForLevel(
      String level, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_srsPrefix$level', json.encode(data));
  }

  // SM2-lite update: ease (1.3-2.5), intervalDays, repetitions, lastReviewedAt
  static Map<String, dynamic> updateSrsOnAnswer({
    required Map<String, dynamic> current,
    required bool isCorrect,
  }) {
    final double ease = (current['ease'] ?? 2.3).toDouble();
    final int reps = (current['reps'] ?? 0) as int;
    final int interval = (current['interval'] ?? 0) as int;

    double newEase = ease + (isCorrect ? 0.1 : -0.2);
    if (newEase < 1.3) newEase = 1.3;
    if (newEase > 2.5) newEase = 2.5;

    int newReps = isCorrect ? reps + 1 : 0;
    int newInterval;
    if (!isCorrect) {
      newInterval = 1; // review tomorrow on fail
    } else if (newReps <= 1) {
      newInterval = 1;
    } else if (newReps == 2) {
      newInterval = 3;
    } else {
      newInterval = (interval * newEase).round().clamp(1, 3650);
    }

    return {
      'ease': newEase,
      'reps': newReps,
      'interval': newInterval,
      'lastReviewedAt': DateTime.now().toIso8601String(),
    };
  }

  static bool isDue(Map<String, dynamic> data, DateTime today) {
    try {
      final last = DateTime.parse(
          (data['lastReviewedAt'] ?? today.toIso8601String()) as String);
      final interval = (data['interval'] ?? 0) as int;
      final dueDate = DateTime(last.year, last.month, last.day)
          .add(Duration(days: interval));
      final dToday = DateTime(today.year, today.month, today.day);
      return !dueDate.isAfter(dToday);
    } catch (_) {
      return true;
    }
  }

  static Future<int> _getTotalFavorites() async {
    try {
      final favorites = await FirestoreSync.getFavorites();
      return favorites.length;
    } catch (e) {
      return 0;
    }
  }

  static double _calculateAccuracy(
      LevelStats levelStats, int correct, int total) {
    if (total == 0) return levelStats.accuracy;

    final totalAnswers = levelStats.wordsLearned + total;
    final totalCorrect =
        (levelStats.accuracy * levelStats.wordsLearned) + correct;

    return totalAnswers > 0 ? totalCorrect / totalAnswers : 0.0;
  }

  static double _calculateAverageScore(
      double currentAverage, int currentCount, double newScore) {
    if (currentCount == 0) return newScore;

    final totalScore = (currentAverage * currentCount) + newScore;
    return totalScore / (currentCount + 1);
  }

  static int _calculateStreak(LearningStats stats, DateTime now) {
    final lastStudy = stats.lastStudyDate;
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastStudy.year, lastStudy.month, lastStudy.day);
    final daysDifference = today.difference(lastDay).inDays;

    // 首次或沒有有效記錄時，從1開始
    if (stats.currentStreak <= 0) {
      return 1;
    }

    if (daysDifference == 0) {
      return stats.currentStreak; // 同一天不增加
    } else if (daysDifference == 1) {
      return stats.currentStreak + 1; // 隔天連續
    } else {
      return 1; // 中斷後重置為1（今日學習）
    }
  }

  static String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _getWeekKey(DateTime date) {
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    return '${weekStart.year}-W${_getWeekNumber(weekStart)}';
  }

  static int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return (daysSinceFirstDay / 7).ceil();
  }

  static Future<LearningStats> _ensureAchievementsCatalog(
      LearningStats stats) async {
    return await _buildAchievementsWithProgress(stats);
  }

  static Future<LearningStats> _buildAchievementsWithProgress(
      LearningStats stats) async {
    final catalog = _achievementCatalog();
    final existing = {for (final a in stats.achievements) a.id: a};
    final computed = <Achievement>[];

    for (final def in catalog) {
      final id = def['id'] as String;
      final title = def['title'] as String;
      final description = def['description'] as String;
      final icon = def['icon'] as String;
      final target = def['target'] as int;
      final type = def['type'] as String; // 'words' or 'streak'

      final progress =
          type == 'words' ? stats.totalWordsLearned : stats.currentStreak;
      final isUnlocked = progress >= target;
      final unlockedAt =
          isUnlocked ? (existing[id]?.unlockedAt ?? DateTime.now()) : null;

      computed.add(Achievement(
        id: id,
        title: title,
        description: description,
        icon: icon,
        isUnlocked: isUnlocked,
        unlockedAt: unlockedAt,
        progress: progress,
        target: target,
      ));
    }

    return stats.copyWith(achievements: computed);
  }

  static List<Map<String, Object>> _achievementCatalog() {
    return [
      {
        'id': 'words_100',
        'title': '單字新手',
        'description': '學習了100個單字',
        'icon': '🎯',
        'target': 100,
        'type': 'words',
      },
      {
        'id': 'words_500',
        'title': '單字達人',
        'description': '學習了500個單字',
        'icon': '🏆',
        'target': 500,
        'type': 'words',
      },
      {
        'id': 'words_1000',
        'title': '單字高手',
        'description': '學習了1000個單字',
        'icon': '🔥',
        'target': 1000,
        'type': 'words',
      },
      {
        'id': 'words_2000',
        'title': '單字大師',
        'description': '學習了2000個單字',
        'icon': '💪',
        'target': 2000,
        'type': 'words',
      },
      {
        'id': 'words_3000',
        'title': '單字宗師',
        'description': '學習了3000個單字',
        'icon': '🔮',
        'target': 3000,
        'type': 'words',
      },
      {
        'id': 'words_4000',
        'title': '單字達人',
        'description': '學習了4000個單字',
        'icon': '👑',
        'target': 4000,
        'type': 'words',
      },
      {
        'id': 'words_5000',
        'title': '單字大神',
        'description': '學習了5000個單字',
        'icon': '🔥',
        'target': 5000,
        'type': 'words',
      },
      {
        'id': 'words_6000',
        'title': 'HSAT',
        'description': '學習了6000個單字',
        'icon': '🎓',
        'target': 6000,
        'type': 'words',
      },
      {
        'id': 'streak_7',
        'title': '一週堅持',
        'description': '連續學習7天',
        'icon': '🔥',
        'target': 7,
        'type': 'streak',
      },
      {
        'id': 'streak_30',
        'title': '持之以恆',
        'description': '連續學習30天',
        'icon': '💪',
        'target': 30,
        'type': 'streak',
      },
    ];
  }

  // Removed: _hasAchievement no longer used after catalog-based achievements
}
