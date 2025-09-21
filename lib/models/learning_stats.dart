
// 學習統計數據模型
class LearningStats {
  final int totalWordsLearned;
  final int totalStudyTime; // 分鐘
  final int currentStreak; // 連續學習天數
  final int longestStreak; // 最長連續學習天數
  final DateTime lastStudyDate;
  final Map<String, LevelStats> levelStats;
  final List<Achievement> achievements;
  final Map<String, int> dailyStudyTime; // 日期 -> 學習時間(分鐘)
  final Map<String, int> weeklyProgress; // 週 -> 學習單字數
  final int totalQuizzesTaken;
  final double averageQuizScore;
  final int totalFavorites;

  LearningStats({
    required this.totalWordsLearned,
    required this.totalStudyTime,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastStudyDate,
    required this.levelStats,
    required this.achievements,
    required this.dailyStudyTime,
    required this.weeklyProgress,
    required this.totalQuizzesTaken,
    required this.averageQuizScore,
    required this.totalFavorites,
  });

  factory LearningStats.empty() {
    return LearningStats(
      totalWordsLearned: 0,
      totalStudyTime: 0,
      currentStreak: 0,
      longestStreak: 0,
      lastStudyDate: DateTime.now(),
      levelStats: {},
      achievements: [],
      dailyStudyTime: {},
      weeklyProgress: {},
      totalQuizzesTaken: 0,
      averageQuizScore: 0.0,
      totalFavorites: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalWordsLearned': totalWordsLearned,
      'totalStudyTime': totalStudyTime,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastStudyDate': lastStudyDate.toIso8601String(),
      'levelStats': levelStats.map((k, v) => MapEntry(k, v.toJson())),
      'achievements': achievements.map((a) => a.toJson()).toList(),
      'dailyStudyTime': dailyStudyTime,
      'weeklyProgress': weeklyProgress,
      'totalQuizzesTaken': totalQuizzesTaken,
      'averageQuizScore': averageQuizScore,
      'totalFavorites': totalFavorites,
    };
  }

  factory LearningStats.fromJson(Map<String, dynamic> json) {
    return LearningStats(
      totalWordsLearned: json['totalWordsLearned'] ?? 0,
      totalStudyTime: json['totalStudyTime'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      lastStudyDate: DateTime.parse(json['lastStudyDate'] ?? DateTime.now().toIso8601String()),
      levelStats: (json['levelStats'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, LevelStats.fromJson(v))),
      achievements: (json['achievements'] as List<dynamic>? ?? [])
          .map((a) => Achievement.fromJson(a))
          .toList(),
      dailyStudyTime: Map<String, int>.from(json['dailyStudyTime'] ?? {}),
      weeklyProgress: Map<String, int>.from(json['weeklyProgress'] ?? {}),
      totalQuizzesTaken: json['totalQuizzesTaken'] ?? 0,
      averageQuizScore: (json['averageQuizScore'] ?? 0.0).toDouble(),
      totalFavorites: json['totalFavorites'] ?? 0,
    );
  }

  LearningStats copyWith({
    int? totalWordsLearned,
    int? totalStudyTime,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastStudyDate,
    Map<String, LevelStats>? levelStats,
    List<Achievement>? achievements,
    Map<String, int>? dailyStudyTime,
    Map<String, int>? weeklyProgress,
    int? totalQuizzesTaken,
    double? averageQuizScore,
    int? totalFavorites,
  }) {
    return LearningStats(
      totalWordsLearned: totalWordsLearned ?? this.totalWordsLearned,
      totalStudyTime: totalStudyTime ?? this.totalStudyTime,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      levelStats: levelStats ?? this.levelStats,
      achievements: achievements ?? this.achievements,
      dailyStudyTime: dailyStudyTime ?? this.dailyStudyTime,
      weeklyProgress: weeklyProgress ?? this.weeklyProgress,
      totalQuizzesTaken: totalQuizzesTaken ?? this.totalQuizzesTaken,
      averageQuizScore: averageQuizScore ?? this.averageQuizScore,
      totalFavorites: totalFavorites ?? this.totalFavorites,
    );
  }
}

// 等級統計數據
class LevelStats {
  final String level;
  final int wordsLearned;
  final int totalWords;
  final int studyTime; // 分鐘
  final double accuracy; // 測驗準確率
  final DateTime lastStudied;

  LevelStats({
    required this.level,
    required this.wordsLearned,
    required this.totalWords,
    required this.studyTime,
    required this.accuracy,
    required this.lastStudied,
  });

  double get progress => totalWords > 0 ? wordsLearned / totalWords : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'wordsLearned': wordsLearned,
      'totalWords': totalWords,
      'studyTime': studyTime,
      'accuracy': accuracy,
      'lastStudied': lastStudied.toIso8601String(),
    };
  }

  factory LevelStats.fromJson(Map<String, dynamic> json) {
    return LevelStats(
      level: json['level'] ?? '',
      wordsLearned: json['wordsLearned'] ?? 0,
      totalWords: json['totalWords'] ?? 0,
      studyTime: json['studyTime'] ?? 0,
      accuracy: (json['accuracy'] ?? 0.0).toDouble(),
      lastStudied: DateTime.parse(json['lastStudied'] ?? DateTime.now().toIso8601String()),
    );
  }

  LevelStats copyWith({
    String? level,
    int? wordsLearned,
    int? totalWords,
    int? studyTime,
    double? accuracy,
    DateTime? lastStudied,
  }) {
    return LevelStats(
      level: level ?? this.level,
      wordsLearned: wordsLearned ?? this.wordsLearned,
      totalWords: totalWords ?? this.totalWords,
      studyTime: studyTime ?? this.studyTime,
      accuracy: accuracy ?? this.accuracy,
      lastStudied: lastStudied ?? this.lastStudied,
    );
  }
}

// 成就系統
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int progress;
  final int target;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    this.unlockedAt,
    required this.progress,
    required this.target,
  });

  double get progressPercentage => target > 0 ? progress / target : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'progress': progress,
      'target': target,
    };
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      isUnlocked: json['isUnlocked'] ?? false,
      unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt']) : null,
      progress: json['progress'] ?? 0,
      target: json['target'] ?? 1,
    );
  }

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? progress,
    int? target,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
      target: target ?? this.target,
    );
  }
}

// 學習會話記錄
class StudySession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String level;
  final int wordsStudied;
  final int correctAnswers;
  final int totalAnswers;
  final int studyTime; // 分鐘

  StudySession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.level,
    required this.wordsStudied,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.studyTime,
  });

  double get accuracy => totalAnswers > 0 ? correctAnswers / totalAnswers : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'level': level,
      'wordsStudied': wordsStudied,
      'correctAnswers': correctAnswers,
      'totalAnswers': totalAnswers,
      'studyTime': studyTime,
    };
  }

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'] ?? '',
      startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(json['endTime'] ?? DateTime.now().toIso8601String()),
      level: json['level'] ?? '',
      wordsStudied: json['wordsStudied'] ?? 0,
      correctAnswers: json['correctAnswers'] ?? 0,
      totalAnswers: json['totalAnswers'] ?? 0,
      studyTime: json['studyTime'] ?? 0,
    );
  }
}
