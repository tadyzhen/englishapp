import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'firestore_sync.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'firebase_options.dart';
import 'dictionary_webview.dart';
import 'screens/modern_login_screen.dart';
import 'screens/main_navigation.dart';

// Utility class for shared functionality
class AppUtils {
  // Show error message in a snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // Handle haptic feedback
  static Future<void> triggerHapticFeedback() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 50);
    }
  }
}

// ========== AppSettings 狀態管理 ==========
class AppSettings extends ChangeNotifier {
  ThemeMode themeMode;
  bool autoSpeak;
  double speechRate;
  double speechPitch;
  double speechVolume;
  Map<String, String>? ttsVoice;

  AppSettings({
    required this.themeMode,
    this.autoSpeak = false,
    this.speechRate = 0.4,
    this.speechPitch = 1.0,
    this.speechVolume = 1.0,
    this.ttsVoice,
  });

  void setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('themeMode', mode == ThemeMode.dark ? 'dark' : 'light');
  }

  void setAutoSpeak(bool value) async {
    autoSpeak = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('autoSpeak', value);
  }

  void setSpeechRate(double rate) async {
    speechRate = rate;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('speechRate', rate);
  }

  void setSpeechPitch(double pitch) async {
    speechPitch = pitch;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('speechPitch', pitch);
  }

  void setSpeechVolume(double volume) async {
    speechVolume = volume;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('speechVolume', volume);
  }

  void setTtsVoice(Map<String, String> voice) async {
    ttsVoice = voice;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ttsVoice', json.encode(voice));
  }

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    String theme = prefs.getString('themeMode') ?? 'light';
    bool autoSpeak = prefs.getBool('autoSpeak') ?? false;
    double speechRate = prefs.getDouble('speechRate') ?? 0.4;
    double speechPitch = prefs.getDouble('speechPitch') ?? 1.0;
    double speechVolume = prefs.getDouble('speechVolume') ?? 1.0;
    Map<String, String>? ttsVoice;
    String? voiceString = prefs.getString('ttsVoice');
    if (voiceString != null) {
      ttsVoice = Map<String, String>.from(json.decode(voiceString));
    }

    return AppSettings(
      themeMode: theme == 'dark' ? ThemeMode.dark : ThemeMode.light,
      autoSpeak: autoSpeak,
      speechRate: speechRate,
      speechPitch: speechPitch,
      speechVolume: speechVolume,
      ttsVoice: ttsVoice,
    );
  }
}

class SettingsProvider extends InheritedNotifier<AppSettings> {
  const SettingsProvider({
    super.key,
    required super.notifier,
    required super.child,
  });
  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsProvider>()!.notifier!;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }

  // Start the app after Firebase is ready
  runApp(const EnglishApp());
}

class EnglishApp extends StatefulWidget {
  const EnglishApp({super.key});

  @override
  State<EnglishApp> createState() => _EnglishAppState();
}

class _EnglishAppState extends State<EnglishApp> {
  AppSettings? _settings;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AppSettings.load();
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoadingSettings = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      // Use default settings if loading fails
      if (mounted) {
        setState(() {
          _settings = AppSettings(themeMode: ThemeMode.system);
          _isLoadingSettings = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a simple loading screen while settings are loading
    if (_isLoadingSettings || _settings == null) {
      return MaterialApp(
        title: 'English Learning App',
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading...', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    }

    return SettingsProvider(
      notifier: _settings!,
      child: AnimatedBuilder(
        animation: _settings!,
        builder: (context, child) {
          return MaterialApp(
            title: 'English Learning App',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: _settings!.themeMode,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  String? _loginMethod;
  String? _handledUid; // ensure we only prompt once per user per session

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loginMethod = prefs.getString('login_method');

      if (mounted) {
        setState(() {
          _loginMethod = loginMethod;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking auth state: $e');
      if (mounted) {
        setState(() {
          _loginMethod = null;
          _isLoading = false;
        });
      }
    }
  }

  // Re-check auth state after login/logout actions
  Future<void> _refreshAuthState() async {
    // Re-check the auth state from storage and rebuild
    await _checkAuthState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Handle authenticated users and guest mode via Firebase stream
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking Firebase auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If Firebase user exists -> Main
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          // After first frame, prompt cloud/local choice once per user if needed
          if (_handledUid != user.uid) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _promptCloudChoiceOnce(user.uid);
            });
          }
          return const MainNavigation();
        }

        // If guest mode flag set -> Main
        if (_loginMethod == 'guest') {
          return const MainNavigation();
        }

        // Otherwise show login screen
        return ModernLoginScreen(onLoginSuccess: _refreshAuthState);
      },
    );
  }

  Future<void> _promptCloudChoiceOnce(String uid) async {
    if (!mounted) return;
    // avoid duplicate prompts per session per uid
    if (_handledUid == uid) return;

    try {
      // Only prompt right after a fresh login
      final prefs = await SharedPreferences.getInstance();
      final justLoggedIn = prefs.getBool('just_logged_in') ?? false;
      bool recentSignIn = false;
      try {
        final user = FirebaseAuth.instance.currentUser;
        final last = user?.metadata.lastSignInTime;
        if (last != null) {
          final now = DateTime.now();
          recentSignIn = now.difference(last).inSeconds <= 10;
        }
      } catch (_) {}
      if (!justLoggedIn && !recentSignIn) {
        return;
      }

      // Small delay to ensure current route is fully built
      await Future.delayed(const Duration(milliseconds: 120));

      // Fetch cloud data
      final cloudKnown = await FirestoreSync.getKnownByLevel();
      final cloudFavs = await FirestoreSync.getFavorites();
      final bool cloudHasData =
          cloudKnown.values.any((l) => l.isNotEmpty) || cloudFavs.isNotEmpty;

      // Always prompt if cloud has any data
      if (!mounted) return;
      // Now mark this uid as handled to avoid duplicate prompts
      _handledUid = uid;
      String? choice;
      try {
        choice = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (ctx) {
            if (cloudHasData) {
              return AlertDialog(
                title: const Text('發現雲端紀錄'),
                content: const Text('偵測到您的雲端已有學習紀錄，請選擇要使用雲端記錄或以本機覆蓋雲端。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop('useCloud'),
                    child: const Text('使用雲端記錄'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop('overwriteCloud'),
                    child: const Text('覆蓋雲端記錄'),
                  ),
                ],
              );
            } else {
              return AlertDialog(
                title: const Text('雲端尚無紀錄'),
                content: const Text('目前雲端還沒有您的學習紀錄，是否要將本機紀錄上傳到雲端？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop('skip'),
                    child: const Text('稍後再說'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop('overwriteCloud'),
                    child: const Text('上傳到雲端'),
                  ),
                ],
              );
            }
          },
        );
      } catch (_) {
        // Fallback: try again once more after a short delay
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 150));
        choice = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (ctx) {
            if (cloudHasData) {
              return AlertDialog(
                title: const Text('發現雲端紀錄'),
                content: const Text('偵測到您的雲端已有學習紀錄，請選擇要使用雲端記錄或以本機覆蓋雲端。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop('useCloud'),
                    child: const Text('使用雲端記錄'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop('overwriteCloud'),
                    child: const Text('覆蓋雲端記錄'),
                  ),
                ],
              );
            } else {
              return AlertDialog(
                title: const Text('雲端尚無紀錄'),
                content: const Text('目前雲端還沒有您的學習紀錄，是否要將本機紀錄上傳到雲端？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop('skip'),
                    child: const Text('稍後再說'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop('overwriteCloud'),
                    child: const Text('上傳到雲端'),
                  ),
                ],
              );
            }
          },
        );
      }

      if (choice == null) {
        await prefs.setBool('just_logged_in', false);
        return;
      }

      final levels = ['1','2','3','4','5','6'];

      if (choice == 'useCloud') {
        // Handle legacy mapping if needed
        Map<String, List<String>> byLevel = Map.fromEntries(
          cloudKnown.entries.where((e) => e.key != '_legacy'),
        );
        if (cloudKnown.containsKey('_legacy')) {
          // Map legacy knownWords to levels by reading assets
          try {
            String data = await rootBundle.loadString('assets/words.json');
            List<dynamic> jsonResult = json.decode(data);
            final wordToLevel = <String, String>{};
            for (var item in jsonResult) {
              final w = Word.fromJson(item);
              wordToLevel[w.english] = w.level;
            }
            final legacyList = cloudKnown['_legacy'] ?? <String>[];
            final Map<String, List<String>> migrated = { for (var lv in levels) lv: <String>[] };
            for (final eng in legacyList) {
              final lv = wordToLevel[eng];
              if (lv != null && migrated.containsKey(lv)) {
                migrated[lv]!.add(eng);
              }
            }
            // merge with existing byLevel
            for (final lv in levels) {
              final existing = byLevel[lv] ?? <String>[];
              final merged = {...existing, ...migrated[lv]!}.toList();
              byLevel[lv] = merged;
            }
          } catch (_) {}
        }

        // Write cloud data to local prefs
        for (final lv in levels) {
          await prefs.setStringList('known_$lv', byLevel[lv] ?? <String>[]);
        }
        await prefs.setStringList('favorite_words', cloudFavs);
      } else if (choice == 'overwriteCloud') {
        // Collect local data and upload to cloud
        for (final lv in levels) {
          final local = prefs.getStringList('known_$lv') ?? <String>[];
          await FirestoreSync.uploadKnownWordsForLevel(lv, local);
        }
        final localFavs = prefs.getStringList('favorite_words') ?? <String>[];
        await FirestoreSync.uploadFavorites(localFavs);
      } else if (choice == 'skip') {
        // do nothing, user chose to postpone; just reset the flag
        await prefs.setBool('just_logged_in', false);
        return;
      }
      // reset the flag after handling
      await prefs.setBool('just_logged_in', false);
    } catch (e) {
      // Silent; do not block UI
    }
  }
}

class LevelSelectPage extends StatefulWidget {
  const LevelSelectPage({super.key});
  @override
  State<LevelSelectPage> createState() => _LevelSelectPageState();
}

class _LevelSelectPageState extends State<LevelSelectPage> {
  final List<String> levels = ['1', '2', '3', '4', '5', '6'];
  bool isResetting = false;
  List<Word> favoriteWords = [];
  // Progress states
  Map<String, int> _levelTotals = {};
  Map<String, int> _levelKnowns = {};
  int _totalKnown = 0;
  int _totalWords = 0;

  @override
  void initState() {
    super.initState();
    _computeProgress();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recompute when this page becomes active again
    _computeProgress();
  }

  Future<void> _computeProgress() async {
    // Load all words from asset and compute totals per level
    String data = await rootBundle.loadString('assets/words.json');
    List<dynamic> jsonResult = json.decode(data);
    final allWords = jsonResult.map((item) => Word.fromJson(item)).toList();
    final totals = <String, int>{}..addEntries(levels.map((l) => MapEntry(l, 0)));
    for (final w in allWords) {
      if (totals.containsKey(w.level)) {
        totals[w.level] = (totals[w.level] ?? 0) + 1;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final knowns = <String, int>{};
    int totalKnown = 0;
    int totalWords = 0;
    for (final lv in levels) {
      final knownList = prefs.getStringList('known_$lv') ?? <String>[];
      knowns[lv] = knownList.length;
      totalKnown += knownList.length;
      totalWords += totals[lv] ?? 0;
    }
    if (!mounted) return;
    setState(() {
      _levelTotals = totals;
      _levelKnowns = knowns;
      _totalKnown = totalKnown;
      _totalWords = totalWords;
    });
  }

  Future<void> resetAllProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('確定要重置所有進度嗎？'),
        content: const Text('這將清除所有熟知記錄與收藏，且無法復原。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('確定重置', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        isResetting = true;
      });
      final prefs = await SharedPreferences.getInstance();
      for (var level in levels) {
        await prefs.remove('known_$level');
      }
      // 同步清除收藏
      await prefs.remove('favorite_words');
      // 雲端同步（非阻塞）
      try {
        FirestoreSync.uploadFavorites([]).catchError((_) {});
      } catch (_) {}
      if (mounted) {
        setState(() {
          isResetting = false;
        });
        // Recompute progress after reset
        _computeProgress();
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                '已重置',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: const Text('所有熟知記錄與收藏已重置'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    '確定',
                    style: TextStyle(color: Color(0xFF007AFF)),
                  ),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> loadFavoriteWords() async {
    final prefs = await SharedPreferences.getInstance();
    // 1) 先拿本機收藏
    final localFavs = prefs.getStringList('favorite_words') ?? [];
    List<String> mergedFavs = List.from(localFavs);
    try {
      // 2) 從雲端抓收藏，若有資料與本機合併並回寫本機
      final cloudFavs = await FirestoreSync.getFavorites();
      if (cloudFavs.isNotEmpty) {
        mergedFavs = {...localFavs, ...cloudFavs}.toList();
        await prefs.setStringList('favorite_words', mergedFavs);
      }
    } catch (_) {}

    String data = await rootBundle.loadString('assets/words.json');
    List<dynamic> jsonResult = json.decode(data);
    List<Word> allWords = jsonResult.map((item) => Word.fromJson(item)).toList();
    setState(() {
      favoriteWords = allWords.where((w) => mergedFavs.contains(w.english)).toList();
    });
  }

  void showSettingsDialog() {
    showDialog(context: context, builder: (ctx) => const SettingsDialog());
  }

  // (removed) _showLevelOptionsDialog: 已改為直接點等級進入 A–Z 子集合

  // （已移除）_getWordCountForLevel：測驗頁面自帶計數函式


  // (removed) _showQuizOptions: 測驗設定已移至 QuizOptionsPage 分頁

  Future<List<Word>> _loadWordsForLevel(String level) async {
    String data = await rootBundle.loadString('assets/words.json');
    List<dynamic> jsonResult = json.decode(data);
    return jsonResult
        .map((item) => Word.fromJson(item))
        .where((word) => word.level == level)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('高嚴凱是給學測7000單'),
        actions: [
          IconButton(
            icon: const Icon(Icons.book),
            tooltip: '所有單字',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllWordsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.star),
            tooltip: '收藏',
            onPressed: () async {
              await loadFavoriteWords();
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FavoritePage(favoriteWords: favoriteWords),
                ),
              ).then((_) => loadFavoriteWords());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重置記錄',
            onPressed: isResetting ? null : resetAllProgress,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 總進度（標題下方長條進度）
            Builder(builder: (context) {
              final total = _totalWords;
              final known = _totalKnown;
              final progress = total == 0 ? 0.0 : (known / total);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('目前單字總進度：$known / $total (${(progress * 100).toStringAsFixed(1)}%)'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                  ),
                ],
              );
            }),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                itemCount: levels.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, idx) {
                  final level = levels[idx];
                  return GestureDetector(
                    onTap: () async {
                      final words = await _loadWordsForLevel(level);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlphabetGroupsPage(level: level, words: words),
                        ),
                      ).then((_) => _computeProgress());
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF232323)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF444444)
                              : const Color(0xFFE5E5EA),
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '等級 $level',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : (Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.color ??
                                            const Color(0xFF222222)),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Builder(builder: (context) {
                                final total = _levelTotals[level] ?? 0;
                                final known = _levelKnowns[level] ?? 0;
                                final progress = total == 0 ? 0.0 : known / total;
                                return Column(
                                  children: [
                                    LinearProgressIndicator(value: progress, minHeight: 8),
                                    const SizedBox(height: 6),
                                    Text('$known / $total (${(progress * 100).toStringAsFixed(0)}%)',
                                        style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A–Z 子集合頁面：點等級後先列表
class AlphabetGroupsPage extends StatelessWidget {
  final String level;
  final List<Word> words;
  const AlphabetGroupsPage({super.key, required this.level, required this.words});

  Map<String, List<Word>> _groupByAlphabet(List<Word> words) {
    final map = <String, List<Word>>{};
    for (final w in words) {
      final first = (w.english.split('/').first.trim());
      if (first.isEmpty) continue;
      final letter = first[0].toUpperCase();
      if (!RegExp(r'^[A-Z]').hasMatch(letter)) {
        // 非英文字母開頭歸類到 '#'
        map.putIfAbsent('#', () => []).add(w);
      } else {
        map.putIfAbsent(letter, () => []).add(w);
      }
    }
    // 排序每組
    for (final k in map.keys) {
      map[k]!.sort((a, b) => a.english.toLowerCase().compareTo(b.english.toLowerCase()));
    }
    return map;
  }

  Future<Set<String>> _loadKnownSet() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('known_$level') ?? <String>[]).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByAlphabet(words);
    final letters = grouped.keys.toList()..sort();
    return FutureBuilder<Set<String>>(
      future: _loadKnownSet(),
      builder: (context, snapshot) {
        final knownSet = snapshot.data ?? {};
        return Scaffold(
          appBar: AppBar(title: Text('等級 $level - A–Z 子集合')),
          body: ListView.separated(
            itemCount: letters.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final letter = letters[index];
              final list = grouped[letter]!;
              final total = list.length;
              final known = list.where((w) => knownSet.contains(w.english)).length;
              final progress = total == 0 ? 0.0 : known / total;
              return ListTile(
                title: Text('$letter 組'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: progress, minHeight: 6),
                    const SizedBox(height: 4),
                    Text('$known / $total (${(progress * 100).toStringAsFixed(0)}%)'),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WordListPage(level: level, words: list, groupOrder: letters, currentLetter: letter),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

// 測驗頁籤對應的設定頁面（將測驗設定從主頁移到此處）
class QuizOptionsPage extends StatefulWidget {
  const QuizOptionsPage({super.key});
  @override
  State<QuizOptionsPage> createState() => _QuizOptionsPageState();
}

class _QuizOptionsPageState extends State<QuizOptionsPage> {
  final List<String> quizLevels = ['1', '2', '3', '4', '5', '6', '全部'];
  String? selectedLevel = '全部';
  int questionCount = 10;
  int maxQuestions = 10;
  String quizType = 'ch2en';
  final TextEditingController countController = TextEditingController(text: '10');
  List<String> letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 
                         'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '全部'];
  String? selectedLetter = '全部';

  @override
  void initState() {
    super.initState();
    _updateMaxQuestions();
  }

  Future<void> _updateMaxQuestions() async {
    if (!mounted) return;
    
    int count;
    if (selectedLevel == '全部' && (selectedLetter == null || selectedLetter == '全部')) {
      // 如果等級和字母都選擇「全部」，則使用固定的大題數
      count = 100; // 或其他你認為合適的數字
    } else {
      count = await _getWordCountForLevel(selectedLevel ?? '全部');
    }
    
    if (!mounted) return;
    
    setState(() {
      maxQuestions = count;
      if (questionCount > maxQuestions) {
        questionCount = maxQuestions;
        countController.text = questionCount.toString();
      }
    });
  }

  Future<int> _getWordCountForLevel(String level) async {
    try {
      String data = await rootBundle.loadString('assets/words.json');
      List<dynamic> jsonResult = json.decode(data);
      List<Word> words = jsonResult.map((item) => Word.fromJson(item)).toList();
      if (level == '全部') return words.length;
      return words.where((w) => w.level == level).length;
    } catch (_) {
      return 10;
    }
  }

  void _startQuiz() async {
    final level = selectedLevel == '全部' ? null : selectedLevel;
    final letter = selectedLetter == '全部' ? null : selectedLetter;
    
    // Build the subset
    String data = await rootBundle.loadString('assets/words.json');
    List<dynamic> jsonResult = json.decode(data);
    List<Word> all = jsonResult.map((item) => Word.fromJson(item)).toList();
    
    // 過濾單字
    List<Word> filtered = all.where((w) {
      bool matchesLevel = level == null || w.level == level;
      bool matchesLetter = letter == null || 
          (w.english.isNotEmpty && 
           w.english[0].toUpperCase() == letter.toUpperCase());
      return matchesLevel && matchesLetter;
    }).toList();
    
    // 確保有足夠的單字
    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('沒有找到符合條件的單字，請調整篩選條件')),
        );
      }
      return;
    }
    if (!mounted) return;
    
    // 如果選擇了特定等級且字母為「全部」，則使用用戶選擇的題數
    // 否則使用所有符合條件的單字
    final int actualQuestionCount = 
        (level != null && (letter == null || letter == '全部')) 
            ? questionCount 
            : filtered.length;
    
    // 確保不超過可用單字數量
    final int finalQuestionCount = actualQuestionCount > filtered.length 
        ? filtered.length 
        : actualQuestionCount;
    
    // 如果用戶選擇的題數大於可用單字數量，顯示提示
    if (actualQuestionCount > filtered.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('可用的單字數量為 ${filtered.length} 個，將使用全部可用單字'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPage(
          type: quizType,
          level: level,
          questionCount: finalQuestionCount,
          quizSubset: filtered,
          letter: letter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('測驗設定')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. 選擇測驗等級', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: quizLevels.map((level) {
                final isSelected = selectedLevel == level;
                return FilterChip(
                  label: Text('等級 $level'),
                  selected: isSelected,
                  onSelected: (selected) async {
                    if (selected) {
                      setState(() => selectedLevel = level);
                      await _updateMaxQuestions();
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // 只有在選擇了特定等級且字母為「全部」時才顯示題數選擇
            if (selectedLevel != '全部' && (selectedLetter == null || selectedLetter == '全部')) ...[
              const Text('2. 選擇測驗題數', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: countController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: '題數 (1-$maxQuestions)',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final count = int.tryParse(value) ?? 0;
                        if (count > 0 && count <= maxQuestions) {
                          setState(() => questionCount = count);
                        }
                      },
                      onSubmitted: (_) => _startQuiz(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('最多: $maxQuestions 題'),
                ],
              ),
              Slider(
                value: questionCount.toDouble(),
                min: 1,
                max: (maxQuestions > 1 ? maxQuestions : 1).toDouble(),
                divisions: (maxQuestions > 1 ? maxQuestions - 1 : 1),
                label: questionCount.toString(),
                onChanged: (value) {
                  setState(() {
                    questionCount = value.toInt();
                    countController.text = questionCount.toString();
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
            const Text('3. 選擇測驗模式', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<String>(
              title: const Text('題目顯示中文（選英文）'),
              value: 'ch2en',
              groupValue: quizType,
              onChanged: (v) => setState(() => quizType = v!),
            ),
            RadioListTile<String>(
              title: const Text('題目顯示英文（選中文）'),
              value: 'en2ch',
              groupValue: quizType,
              onChanged: (v) => setState(() => quizType = v!),
            ),
            const SizedBox(height: 12),
            const Text('4. 選擇測驗字母', style: TextStyle(fontWeight: FontWeight.bold)),
            FutureBuilder(
              future: _getLetters(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Wrap(
                    spacing: 8.0,
                    children: snapshot.data!.map((letter) {
                      final isSelected = selectedLetter == letter;
                      return FilterChip(
                        label: Text(letter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            selectedLetter = selected ? letter : null;
                            _updateMaxQuestions(); // 更新最大題數
                          });
                        },
                      );
                    }).toList(),
                  );
                } else {
                  return const CircularProgressIndicator();
                }
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _startQuiz,
                icon: const Icon(Icons.play_arrow),
                label: const Text('開始測驗'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>> _getLetters() async {
    return ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 
            'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '全部'];
  }
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late FlutterTts flutterTts;
  final List<Map<String, String>> _displayVoices = [];
  String? _selectedVoiceName;

  // Predefined list of desired voices and their Chinese names.
  final List<Map<String, String>> preferredVoices = [
    {'locale': 'en-US', 'displayName': '美國語音'},
    {'locale': 'en-GB', 'displayName': '英國語音'},
    {'locale': 'en-AU', 'displayName': '澳洲語音'},
    {'locale': 'en-IN', 'displayName': '印度語音'},
    {'locale': 'en-CA', 'displayName': '加拿大語音'},
  ];

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    // Use a post-frame callback to access the provider safely.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVoices();
    });
  }

  Future<void> _loadVoices() async {
    try {
      // Ensure context is mounted before using it.
      if (!mounted) return;
      final settings = SettingsProvider.of(context);

      List<dynamic> allVoices = await flutterTts.getVoices;
      List<Map<String, String>> availableVoices = allVoices
          .map(
            (v) => {
              "name": v['name'] as String,
              "locale": v['locale'] as String,
            },
          )
          .toList();

      List<Map<String, String>> tempDisplayVoices = [];

      for (var prefVoice in preferredVoices) {
        final foundVoice = availableVoices.firstWhere(
          (v) => v['locale'] == prefVoice['locale'],
          orElse: () => {},
        );

        if (foundVoice.isNotEmpty) {
          tempDisplayVoices.add({
            'name': foundVoice['name']!,
            'locale': foundVoice['locale']!,
            'displayName': prefVoice['displayName']!,
          });
        }
      }

      // Fallback if no preferred voices are found
      if (tempDisplayVoices.isEmpty) {
        tempDisplayVoices = availableVoices
            .where((v) => v['locale']!.startsWith('en-'))
            .take(5)
            .map((v) => {...v, 'displayName': v['name']!})
            .toList();
      }

      if (!mounted) return;

      setState(() {
        _displayVoices.clear();
        _displayVoices.addAll(tempDisplayVoices);

        _selectedVoiceName = settings.ttsVoice?['name'];

        if (_selectedVoiceName == null ||
            !_displayVoices.any((v) => v['name'] == _selectedVoiceName)) {
          if (_displayVoices.isNotEmpty) {
            _selectedVoiceName = _displayVoices.first['name'];
            settings.setTtsVoice({
              'name': _displayVoices.first['name']!,
              'locale': _displayVoices.first['locale']!,
            });
          } else {
            _selectedVoiceName = null;
          }
        }
      });
    } catch (e) {
      // print("Error loading voices: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsProvider.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('設定', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Theme
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('主題模式', style: TextStyle(fontSize: 18)),
                DropdownButton<ThemeMode>(
                  value: settings.themeMode,
                  items: const [
                    DropdownMenuItem(value: ThemeMode.light, child: Text('亮')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('暗')),
                  ],
                  onChanged: (mode) {
                    if (mode != null) settings.setThemeMode(mode);
                  },
                ),
              ],
            ),
            const Divider(),
            // Auto-speak
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('自動播放語音', style: TextStyle(fontSize: 18)),
                Switch(
                  value: settings.autoSpeak,
                  onChanged: (v) => settings.setAutoSpeak(v),
                ),
              ],
            ),
            const Divider(),
            // Speech Rate
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('語速', style: TextStyle(fontSize: 18)),
                Slider(
                  value: settings.speechRate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: settings.speechRate.toStringAsFixed(1),
                  onChanged: (rate) => settings.setSpeechRate(rate),
                ),
              ],
            ),
            const Divider(),
            // Speech Pitch
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('音高', style: TextStyle(fontSize: 18)),
                Slider(
                  value: settings.speechPitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: settings.speechPitch.toStringAsFixed(1),
                  onChanged: (pitch) => settings.setSpeechPitch(pitch),
                ),
              ],
            ),
            const Divider(),
            // Speech Volume
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('語音音量', style: TextStyle(fontSize: 18)),
                Slider(
                  value: settings.speechVolume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(settings.speechVolume * 100).toInt()}%',
                  onChanged: (volume) => settings.setSpeechVolume(volume),
                ),
              ],
            ),
            const Divider(),
            // Voice Selection
            if (_displayVoices.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('語音', style: TextStyle(fontSize: 18)),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedVoiceName,
                      items: _displayVoices.map((voice) {
                        return DropdownMenuItem<String>(
                          value: voice['name'],
                          child: Text(
                            voice['displayName']!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (name) {
                        if (name != null) {
                          final selectedVoiceMap = _displayVoices.firstWhere(
                            (v) => v['name'] == name,
                          );
                          settings.setTtsVoice({
                            'name': selectedVoiceMap['name']!,
                            'locale': selectedVoiceMap['locale']!,
                          });
                          setState(() {
                            _selectedVoiceName = name;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('關閉', style: TextStyle(color: Color(0xFF007AFF))),
        ),
      ],
    );
  }
}

class Word {
  final String level;
  final String english;
  final String pos;
  final String engPos;
  final String chinese;
  final String? synonyms;
  final String? antonyms;
  final String? example;

  Word({
    required this.level,
    required this.english,
    required this.pos,
    required this.engPos,
    required this.chinese,
    this.synonyms,
    this.antonyms,
    this.example,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      level: json['level'].toString(),
      english: json['word'].toString(),
      pos: json['pos'].toString(),
      engPos: json['output'].toString(),
      chinese: json['chinese'].toString(),
      synonyms: json['synonyms'],
      antonyms: json['antonyms'],
      example: json['example'],
    );
  }
}

class WordQuizPage extends StatefulWidget {
  final String? initialLevel;
  final int? initialWordIndex;
  final List<Word>? subsetWords; // limit quiz to this subset if provided
  final String? subsetLetter; // letter label for UI
  final List<String>? groupOrder; // navigation order of letters within level
  const WordQuizPage({
    super.key,
    this.initialLevel,
    this.initialWordIndex,
    this.subsetWords,
    this.subsetLetter,
    this.groupOrder,
  });
  @override
  State<WordQuizPage> createState() => _WordQuizPageState();
}

class _WordQuizPageState extends State<WordQuizPage> {
  Map<String, List<Word>> levelWords = {};
  String? selectedLevel;
  int currentIndex = 0;
  int knownCount = 0;
  List<Word> words = [];
  bool isFinished = false;
  bool showChinese = false;
  Set<String> knownWords = {};
  Set<String> favoriteWords = {};
  bool isLoading = true;
  late FlutterTts flutterTts;
  bool ttsReady = false;
  bool isSpeaking = false;
  bool _isPressed = false;
  Timer? _longPressTimer;
  bool showCompletionPanel = false;


  // Open Cambridge Dictionary for the current word in WebView
  Future<void> _openDictionary() async {
    try {
      final word = words[currentIndex].english.split(' ').first;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DictionaryWebView(word: word)),
      );
      await AppUtils.triggerHapticFeedback();
    } catch (e) {
      if (mounted) AppUtils.showErrorSnackBar(context, '發生錯誤: $e');
    }
  }

  // Show error message in a snackbar - moved to be accessible by all methods

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    _initTts();
    loadWordsAndProgress();
  }

  Future<void> _initTts() async {
    final settings = SettingsProvider.of(context);
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(settings.speechRate);
    await flutterTts.setPitch(settings.speechPitch);
    await flutterTts.setVolume(settings.speechVolume);
    
    // Configure audio session to not pause background music
    await flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
      IosTextToSpeechAudioMode.spokenAudio,
    );
    
    if (settings.ttsVoice != null) {
      await flutterTts.setVoice(settings.ttsVoice!);
    }

    setState(() {
      ttsReady = true;
    });

    flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => isSpeaking = false);
    });
    flutterTts.setCancelHandler(() {
      if (mounted) setState(() => isSpeaking = false);
    });
    flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => isSpeaking = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initTts();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    flutterTts.stop();
    super.dispose();
  }

  Future<void> speakWord(String word) async {
    if (isSpeaking || !ttsReady) return;
    final textToSpeak = word.replaceAll('/', ' ');
    if (textToSpeak.trim().isEmpty) return;

    setState(() => isSpeaking = true);
    try {
      await _initTts(); // Re-initialize to apply latest settings
      await flutterTts.speak(textToSpeak);
    } catch (e) {
      if (mounted) setState(() => isSpeaking = false);
    }
  }

  Future<void> loadWordsAndProgress() async {
    setState(() {
      isLoading = true;
    });
    String data = await rootBundle.loadString('assets/words.json');
    List<dynamic> jsonResult = json.decode(data);
    Map<String, List<Word>> temp = {};
    for (var item in jsonResult) {
      Word word = Word.fromJson(item);
      temp.putIfAbsent(word.level, () => []).add(word);
    }
    final prefs = await SharedPreferences.getInstance();
    String level = widget.initialLevel ?? temp.keys.first;
    List<Word> wordList;
    if (widget.subsetWords != null && widget.subsetWords!.isNotEmpty) {
      // use provided subset within level
      wordList = List<Word>.from(widget.subsetWords!);
    } else {
      wordList = List<Word>.from(temp[level] ?? []);
    }
    // 1) 先從本機載入
    Set<String> known = {};
    try {
      final prefKnown = prefs.getStringList('known_$level');
      if (prefKnown != null) {
        known = prefKnown.toSet();
      }
    } catch (_) {}
    // 2) 再從雲端拉使用者進度（若雲端有資料則優先使用，並回寫本機）
    try {
      final byLevel = await FirestoreSync.getKnownByLevel();
      final cloud = byLevel[level] ?? [];
      if (cloud.isNotEmpty) {
        // 以雲端為主，並與本機合併避免遺失（取聯集）
        known = {...known, ...cloud}.toSet();
        // 回寫本機，以利離線使用
        await prefs.setStringList('known_$level', known.toList());
      }
    } catch (_) {}
    Set<String> favs = prefs.getStringList('favorite_words')?.toSet() ?? {};

    int firstUnfamiliar = 0;
    if (widget.initialWordIndex != null) {
      firstUnfamiliar = widget.initialWordIndex!;
    } else {
      for (int i = 0; i < wordList.length; i++) {
        if (!known.contains(wordList[i].english)) {
          firstUnfamiliar = i;
          break;
        }
      }
      if (firstUnfamiliar == -1) firstUnfamiliar = 0;
    }

    // Calculate known count for current subset only
    int subsetKnownCount = 0;
    if (widget.subsetWords != null && widget.subsetWords!.isNotEmpty) {
      // For subset mode, count only words in current subset that are known
      subsetKnownCount = wordList.where((w) => known.contains(w.english)).length;
    } else {
      // For full level mode, use total known count
      subsetKnownCount = known.length;
    }

    setState(() {
      levelWords = temp;
      selectedLevel = level;
      words = wordList;
      knownWords = known;
      favoriteWords = favs;
      knownCount = subsetKnownCount;
      currentIndex = widget.initialWordIndex ?? firstUnfamiliar;
      isFinished = subsetKnownCount >= words.length;
      showChinese = false;
      isLoading = false;
    });

    // Show inline completion panel if subset already finished on load
    if ((widget.subsetWords != null && widget.subsetWords!.isNotEmpty) && isFinished) {
      setState(() => showCompletionPanel = true);
    }

    final settings = SettingsProvider.of(context);
    if (settings.autoSpeak && words.isNotEmpty && !isFinished) {
      await Future.delayed(const Duration(milliseconds: 300));
      speakWord(words[currentIndex].english);
    }
  }

  int _findNextUnfamiliarIndex(int fromIndex) {
    for (int i = fromIndex + 1; i < words.length; i++) {
      if (!knownWords.contains(words[i].english)) {
        return i;
      }
    }
    return -1; // No more unfamiliar words
  }


  Future<void> handleSwipe(bool known) async {
    if (isFinished) return;

    String wordKey = words[currentIndex].english;

    // Update known words set based on swipe direction
    if (known) {
      knownWords.add(wordKey);
    } else {
      knownWords.remove(wordKey);
    }

    final nextIndex = _findNextUnfamiliarIndex(currentIndex);

    // Update UI immediately for instant response
    setState(() {
      // Update knownCount to reflect current subset's known words only
      if (widget.subsetWords != null && widget.subsetWords!.isNotEmpty) {
        // For subset mode, count only words in current subset that are known
        knownCount = words.where((w) => knownWords.contains(w.english)).length;
      } else {
        // For full level mode, use total known count
        knownCount = knownWords.length;
      }
      if (nextIndex != -1) {
        currentIndex = nextIndex;
        showChinese = false;
      } else {
        isFinished = true;
      }
    });

    // Perform async operations without blocking UI
    _saveProgressAsync(known, wordKey);

    // Auto-speak immediately if enabled
    final settings = SettingsProvider.of(context);
    if (settings.autoSpeak && !isFinished && currentIndex < words.length) {
      speakWord(words[currentIndex].english);
    }

    // If subset finished, show inline completion panel
    if (isFinished && (widget.subsetWords != null && widget.subsetWords!.isNotEmpty)) {
      setState(() => showCompletionPanel = true);
    }
  }

  // Async method to save progress without blocking UI
  Future<void> _saveProgressAsync(bool known, String wordKey) async {
    try {
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String key = 'known_${selectedLevel ?? ''}';
      await prefs.setStringList(key, knownWords.toList());

      // Cloud sync (fire and forget)
      if (selectedLevel != null && selectedLevel!.isNotEmpty) {
        FirestoreSync
                .uploadKnownWordsForLevel(selectedLevel!, knownWords.toList())
            .catchError((e) {
          // Silently handle errors for offline fallback
        });
      } else {
        // Fallback to legacy field if level not determined
        FirestoreSync.uploadKnownWords(knownWords.toList()).catchError((e) {
          // Silently handle errors for offline fallback
        });
      }
    } catch (e) {
      // Handle any errors silently
    }
  }

  void goToPreviousWord() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        showChinese = false;
      });
    }
  }

  Future<void> addToFavorite(String word) async {
    final prefs = await SharedPreferences.getInstance();
    favoriteWords.add(word);
    await prefs.setStringList('favorite_words', favoriteWords.toList());
    try {
      await FirestoreSync.uploadFavorites(favoriteWords.toList());
    } catch (e) {
      // ignore error, offline fallback
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已加入收藏')));
    }
    setState(() {});
  }

  Widget _buildActionButton(
    String text, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 220,
      height: 52,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('高嚴凱是給學測7000單')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    double progress = words.isEmpty ? 0 : (knownCount / words.length);
    final Color progressColor = const Color(0xFF007AFF);
    final Color cardShadow = Colors.black.withOpacity(0.07);
    final double cardRadius = 32;

    return Scaffold(
      appBar: AppBar(title: const Text('高嚴凱是給學測7000單')),
      body: Stack(
        children: [
          // 進度條
          Positioned(
            top: 36,
            left: 32,
            right: 32,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE5E5EA),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$knownCount / ${words.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF222222),
                  ),
                ),
              ],
            ),
          ),
          // 單字卡或完成畫面
          Center(
            child: showCompletionPanel
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Color(0xFFFFC700),
                        size: 100,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '完成 ${widget.subsetLetter ?? ''} 組單字',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '熟知單字：$knownCount / ${words.length}',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildActionButton(
                        '重新開始',
                        Icons.refresh,
                        Colors.blue,
                        () async {
                          // Reset known words for current subset only
                          if (widget.subsetWords != null && widget.subsetWords!.isNotEmpty) {
                            // Remove only current subset words from knownWords
                            for (final word in words) {
                              knownWords.remove(word.english);
                            }
                            
                            // Update known count for current subset
                            knownCount = 0;
                            
                            // Save updated progress
                            final prefs = await SharedPreferences.getInstance();
                            String key = 'known_${selectedLevel ?? ''}';
                            await prefs.setStringList(key, knownWords.toList());
                            
                            // Cloud sync
                            if (selectedLevel != null && selectedLevel!.isNotEmpty) {
                              FirestoreSync.uploadKnownWordsForLevel(selectedLevel!, knownWords.toList()).catchError((e) {});
                            }
                          }
                          
                          setState(() {
                            showCompletionPanel = false;
                            currentIndex = 0;
                            isFinished = false;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (widget.groupOrder != null &&
                          widget.subsetLetter != null &&
                          widget.groupOrder!.indexOf(widget.subsetLetter!) <
                              widget.groupOrder!.length - 1)
                        _buildActionButton(
                          '下一組',
                          Icons.arrow_forward,
                          Colors.green,
                          () async {
                            // Find next letter in group order
                            final currentIndex = widget.groupOrder!.indexOf(widget.subsetLetter!);
                            if (currentIndex >= 0 && currentIndex + 1 < widget.groupOrder!.length) {
                              final nextLetter = widget.groupOrder![currentIndex + 1];
                              
                              // Load words for next letter
                              String data = await rootBundle.loadString('assets/words.json');
                              List<dynamic> jsonResult = json.decode(data);
                              List<Word> allWords = jsonResult.map((item) => Word.fromJson(item)).toList();
                              
                              // Filter words for next letter in same level
                              List<Word> nextLetterWords = allWords.where((w) {
                                return w.level == selectedLevel && 
                                       w.english.isNotEmpty && 
                                       w.english[0].toUpperCase() == nextLetter;
                              }).toList();
                              
                              if (nextLetterWords.isNotEmpty) {
                                // Navigate to next letter's WordQuizPage
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WordQuizPage(
                                      initialLevel: selectedLevel,
                                      subsetWords: nextLetterWords,
                                      subsetLetter: nextLetter,
                                      groupOrder: widget.groupOrder,
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      const SizedBox(height: 16),
                      _buildActionButton(
                        '測驗本組',
                        Icons.quiz,
                        Colors.purple,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizPage(
                                type: 'ch2en',
                                level: selectedLevel ?? '1',
                                quizSubset: words,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '返回列表',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    ],
                  )
                : Dismissible(
                    key: Key(
                      words[currentIndex].english +
                          words[currentIndex].level +
                          currentIndex.toString(),
                    ),
                    direction: DismissDirection.horizontal,
                    onDismissed: (direction) {
                      if (direction == DismissDirection.startToEnd) {
                        handleSwipe(true);
                      } else if (direction == DismissDirection.endToStart) {
                        handleSwipe(false);
                      }
                    },
                    background: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(cardRadius),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 40),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.check_circle,
                            color: Color(0xFF34C759),
                            size: 60,
                          ),
                          SizedBox(width: 16),
                          Text(
                            '熟知',
                            style: TextStyle(
                              color: Color(0xFF34C759),
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    secondaryBackground: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(cardRadius),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: const [
                          Text(
                            '還未熟悉',
                            style: TextStyle(
                              color: Color(0xFFFF3B30),
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 16),
                          Icon(
                            Icons.cancel,
                            color: Color(0xFFFF3B30),
                            size: 60,
                          ),
                        ],
                      ),
                    ),
                    // 移除下滑收藏相關
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          showChinese = !showChinese;
                        });
                      },
                      onTapDown: (_) {
                        if (mounted) {
                          setState(() => _isPressed = true);
                        }

                        _longPressTimer = Timer(const Duration(milliseconds: 500), () async {
                          if (!mounted) return;

                          // Trigger haptic feedback
                          await HapticFeedback.lightImpact();

                          // Open dictionary immediately
                          _openDictionary();
                        });
                      },
                      onTapUp: (_) {
                        _longPressTimer?.cancel();
                        if (mounted) {
                          setState(() => _isPressed = false);
                        }
                      },
                      onTapCancel: () {
                        _longPressTimer?.cancel();
                        if (mounted) {
                          setState(() => _isPressed = false);
                        }
                      },
                      onDoubleTap: () async {
                        final word = words[currentIndex].english;
                        if (favoriteWords.contains(word)) {
                          favoriteWords.remove(word);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setStringList(
                            'favorite_words',
                            favoriteWords.toList(),
                          );
                          try {
                            await FirestoreSync.uploadFavorites(
                              favoriteWords.toList(),
                            );
                          } catch (e) {
                            // ignore error, offline fallback
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('已移除收藏')));
                          }
                        } else {
                          await addToFavorite(word);
                        }
                        setState(() {});
                      },
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            transform: Matrix4.identity()
                              ..scale(_isPressed ? 0.98 : 1.0),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 100,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF232323)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(cardRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: cardShadow,
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF444444)
                                    : const Color(0xFFE5E5EA),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        words[currentIndex].english,
                                        style: TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : const Color(0xFF222222),
                                        ),
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                        // maxLines: 2, // 可視需求加上
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.volume_up,
                                        size: 36,
                                        color: Color(0xFF007AFF),
                                      ),
                                      onPressed: isSpeaking
                                          ? null
                                          : () => speakWord(
                                                words[currentIndex].english,
                                              ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  words[currentIndex].pos,
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white70
                                        : const Color(0xFF888888),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 24),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 80),
                                  child: showChinese
                                      ? Text(
                                          words[currentIndex].chinese,
                                          key: const ValueKey('chinese'),
                                          style: TextStyle(
                                            fontSize: 32,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.blue[200]
                                                    : const Color(0xFF007AFF),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                          // 星星圖案
                          Positioned(
                            top: 110,
                            left: 40,
                            child: IconButton(
                              icon: Icon(
                                favoriteWords.contains(
                                  words[currentIndex].english,
                                )
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 36,
                              ),
                              onPressed: () async {
                                final word = words[currentIndex].english;
                                if (favoriteWords.contains(word)) {
                                  favoriteWords.remove(word);
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setStringList(
                                    'favorite_words',
                                    favoriteWords.toList(),
                                  );
                                  try {
                                    await FirestoreSync.uploadFavorites(
                                      favoriteWords.toList(),
                                    );
                                  } catch (e) {
                                    // ignore error, offline fallback
                                  }
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('已移除收藏')),
                                    );
                                  }
                                } else {
                                  await addToFavorite(word);
                                }
                                setState(() {});
                              },
                            ),
                          ),
                          // Previous word button
                          Positioned(
                            top: 110,
                            right: 40,
                            child: IconButton(
                              icon: const Icon(Icons.undo),
                              onPressed: goToPreviousWord,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class WordListPage extends StatefulWidget {
  final String level;
  final List<Word> words;
  final List<String>? groupOrder;
  final String? currentLetter;

  const WordListPage({
    super.key,
    required this.level,
    required this.words,
    this.groupOrder,
    this.currentLetter,
  });

  @override
  State<WordListPage> createState() => _WordListPageState();
}

class _WordListPageState extends State<WordListPage> {
  Set<String> _knownWords = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKnownWords();
  }

  Future<void> _loadKnownWords() async {
    final prefs = await SharedPreferences.getInstance();
    final known = prefs.getStringList('known_${widget.level}') ?? [];
    if (mounted) {
      setState(() {
        _knownWords = Set.from(known);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('等級 ${widget.level} - 單字列表')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: widget.words.length,
              itemBuilder: (context, index) {
                final word = widget.words[index];
                final isKnown = _knownWords.contains(word.english);
                return ListTile(
                  title: Text(
                    word.english,
                    style: TextStyle(color: isKnown ? Colors.green : Colors.red),
                  ),
                  subtitle: Text(word.chinese),
                  // onTap functionality removed as requested
                );
              },
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizPage(
                    type: 'ch2en',
                    level: widget.level,
                    quizSubset: widget.words,
                    letter: widget.currentLetter,
                  ),
                ),
              );
            },
            label: const Text('測驗'),
            icon: const Icon(Icons.quiz),
            heroTag: 'quiz_fab',
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WordQuizPage(
                    initialLevel: widget.level,
                    subsetWords: widget.words,
                    subsetLetter: widget.currentLetter,
                    groupOrder: widget.groupOrder,
                  ),
                ),
              ).then((_) => _loadKnownWords()); // Refresh known words when returning
            },
            label: const Text('開始'),
            icon: const Icon(Icons.play_arrow),
            heroTag: 'start_fab',
          ),
        ],
      ),
    );
  }
}

class FavoritePage extends StatefulWidget {
  final List<Word> favoriteWords;
  const FavoritePage({super.key, required this.favoriteWords});
  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  late List<Word> favWords;

  @override
  void initState() {
    super.initState();
    favWords = List.from(widget.favoriteWords);
  }

  Future<void> removeFavorite(String english) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList('favorite_words') ?? [];
    favs.remove(english);
    await prefs.setStringList('favorite_words', favs);
    try {
      await FirestoreSync.uploadFavorites(favs);
    } catch (e) {
      // ignore error, offline fallback
    }
    setState(() {
      favWords.removeWhere((w) => w.english == english);
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已移除收藏')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收藏單字')),
      body: favWords.isEmpty
          ? const Center(child: Text('尚未收藏任何單字'))
          : ListView.separated(
              itemCount: favWords.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final word = favWords[idx];
                return ListTile(
                  title: Text(
                    word.english,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${word.pos}  ${word.chinese}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => removeFavorite(word.english),
                  ),
                );
              },
            ),
    );
  }
}

class QuizPage extends StatefulWidget {
  final String type; // 'ch2en' or 'en2ch'
  final String? level;
  final int? questionCount;
  final List<Word>? quizSubset; // if provided, quiz only these words
  final String? letter; // optional letter filter for level
  const QuizPage({
    super.key,
    required this.type,
    this.level,
    this.questionCount,
    this.quizSubset,
    this.letter,
  });
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<Word> allWords = [];
  List<Word> quizWords = [];
  int current = 0;
  int score = 0;
  List<int> userAnswers = [];
  List<List<Word>> optionsList = [];
  bool _isProcessing = false;
  bool _showAnswer = false;
  bool _isAnswerCorrect = false;
  int? _selectedIndex;
  bool _showAllTranslations = false;

  @override
  void initState() {
    super.initState();
    loadQuiz();
  }

  Future<void> _resetQuiz() async {
    if (mounted) {
      setState(() {
        current = 0;
        score = 0;
        _showAnswer = false;
        _isAnswerCorrect = false;
        _selectedIndex = null;
        _showAllTranslations = false;
        _isProcessing = false;
      });
      await loadQuiz();
    }
  }

  Future<void> loadQuiz() async {
    if (!mounted) return;

    // 1. Load all words from JSON
    String data = await rootBundle.loadString('assets/words.json');
    List<dynamic> jsonResult = json.decode(data);
    allWords = jsonResult.map((item) => Word.fromJson(item)).toList();

    List<Word> filteredWords;

    // 2. Determine the pool of words for the quiz
    if (widget.quizSubset != null && widget.quizSubset!.isNotEmpty) {
      filteredWords = List.from(widget.quizSubset!);
    } else {
      filteredWords = allWords.where((word) {
        bool levelMatch = widget.level == null || word.level == widget.level;
        bool letterMatch = widget.letter == null ||
            word.english.toLowerCase().startsWith(widget.letter!.toLowerCase());
        return levelMatch && letterMatch;
      }).toList();
    }

    filteredWords.shuffle();

    // 3. Determine the final number of questions
    int count = filteredWords.length;
    if (widget.questionCount != null) {
      count = widget.questionCount! < count ? widget.questionCount! : count;
    }
    quizWords = filteredWords.take(count).toList();

    // 4. Generate options for each question
    optionsList = quizWords.map((answer) {
      List<Word> options = [answer];
      List<Word> distractors = allWords
          .where((w) =>
              w.english != answer.english &&
              (widget.level == null || w.level == widget.level))
          .toList();
      distractors.shuffle();
      options.addAll(distractors.take(3));
      options.shuffle();
      return options;
    }).toList();

    // 5. Initialize user answers and update UI
    userAnswers = List.filled(quizWords.length, -1);

    setState(() {});
  }

  void _handleAnswer(int selectedIndex) {
    if (_isProcessing || _showAnswer) return;

    setState(() {
      _selectedIndex = selectedIndex;
      _showAnswer = true;
      final correctIdx = optionsList[current].indexWhere(
        (w) => w.english == quizWords[current].english,
      );
      _isAnswerCorrect = selectedIndex == correctIdx;

      if (userAnswers[current] == -1) {
        if (_isAnswerCorrect) {
          score++;
        }
        userAnswers[current] = selectedIndex;
      }

      if (_isAnswerCorrect) {
        _showAllTranslations = false;
        Future.delayed(const Duration(milliseconds: 500), _nextQuestion);
      } else {
        _showAllTranslations = true;
      }
    });
  }

  void _previousQuestion() {
    if (current > 0) {
      setState(() {
        current--;
        _showAnswer = userAnswers[current] != -1;
        _selectedIndex =
            userAnswers[current] != -1 ? userAnswers[current] : null;
        _isProcessing = false;
        _showAllTranslations = _showAnswer &&
            _selectedIndex != null &&
            optionsList[current][_selectedIndex!].english !=
                quizWords[current].english;
      });
    }
  }

  void _nextQuestion() {
    if (!mounted) return;

    if (current < quizWords.length - 1) {
      setState(() {
        current++;
        _showAnswer = false;
        _selectedIndex = null;
        _isProcessing = false;
        _showAllTranslations = false;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultsPage(
            quizWords: quizWords,
            optionsList: optionsList,
            userAnswers: userAnswers,
            quizType: widget.type,
          ),
        ),
      );
    }
  }

  Future<void> addToFavoriteQuiz(String english) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList('favorite_words') ?? [];
    if (!favs.contains(english)) {
      favs.add(english);
      await prefs.setStringList('favorite_words', favs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入收藏')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (quizWords.isEmpty || optionsList.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final word = quizWords[current];
    final options = optionsList[current];
    final correctIdx = options.indexWhere((w) => w.english == word.english);

    return Scaffold(
      appBar: AppBar(
        title: Text('測驗 (${current + 1}/${quizWords.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetQuiz,
            tooltip: '重新開始測驗',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.type == 'ch2en' ? word.chinese : word.english,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.0,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: List.generate(4, (i) {
                        final opt = options[i];
                        final isCorrect = i == correctIdx;
                        final isSelected = _selectedIndex == i;
                        final showAnswer =
                            _showAnswer && (isCorrect || isSelected);

                        Color? cardColor = Theme.of(context).cardColor;
                        Color? borderColor = Colors.grey[300];
                        BoxShadow? boxShadow;

                        if (showAnswer) {
                          if (isCorrect) {
                            cardColor = Colors.green[50];
                            borderColor = Colors.green;
                          } else if (isSelected) {
                            cardColor = Colors.red[50];
                            borderColor = Colors.red;
                          }
                        } else if (isSelected) {
                          boxShadow = BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          );
                        }

                        return GestureDetector(
                          onTap: _showAnswer ? null : () => _handleAnswer(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: borderColor!,
                                width: 1.5,
                              ),
                              boxShadow: boxShadow != null ? [boxShadow] : null,
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.type == 'ch2en'
                                          ? opt.english
                                          : opt.chinese,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: isSelected &&
                                                !isCorrect &&
                                                _showAnswer
                                            ? Colors.red
                                            : (isCorrect && _showAnswer
                                                ? Colors.green
                                                : null),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_showAllTranslations ||
                                        _showAnswer ||
                                        userAnswers[current] != -1)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4.0,
                                        ),
                                        child: Text(
                                          widget.type == 'ch2en'
                                              ? opt.chinese
                                              : opt.english,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isCorrect && _showAnswer
                                                ? Colors.green[700]
                                                : (isSelected &&
                                                        !isCorrect &&
                                                        _showAnswer
                                                    ? Colors.red[700]
                                                    : Colors.grey[600]),
                                            fontStyle: FontStyle.italic,
                                            fontWeight: isCorrect && _showAnswer
                                                ? FontWeight.bold
                                                : null,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: current > 0 ? _previousQuestion : null,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('上一題'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            minimumSize: const Size(120, 48),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _nextQuestion,
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(
                            current < quizWords.length - 1 ? '下一題' : '查看結果',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            minimumSize: const Size(120, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuizResultsPage extends StatelessWidget {
  final List<Word> quizWords;
  final List<List<Word>> optionsList;
  final List<int> userAnswers;
  final String quizType;

  const QuizResultsPage({
    super.key,
    required this.quizWords,
    required this.optionsList,
    required this.userAnswers,
    required this.quizType,
  });

  Widget build(BuildContext context) {
    int score = 0;
    for (int i = 0; i < quizWords.length; i++) {
      if (userAnswers[i] >= 0) {
        // Only count if answered
        final correctIdx = optionsList[i].indexWhere(
          (w) => w.english == quizWords[i].english,
        );
        if (userAnswers[i] == correctIdx) {
          score++;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('測驗結果 - $score / ${quizWords.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: quizWords.length,
        itemBuilder: (context, index) {
          final word = quizWords[index];
          final options = optionsList[index];
          final userAnswer = userAnswers[index];
          final correctIdx = options.indexWhere(
            (w) => w.english == word.english,
          );
          final isCorrect = userAnswer == correctIdx;
          final userAnswered = userAnswer >= 0;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  Text(
                    '${index + 1}. ${quizType == 'ch2en' ? word.chinese : word.english}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // User's answer
                  if (userAnswered) ...[
                    Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '你的答案: ${options[userAnswer].chinese}',
                          style: TextStyle(
                            color: isCorrect ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ] else ...[
                    const Text(
                      '未回答',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Correct answer
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '正確答案: ${options[correctIdx].chinese}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Options summary
                  const SizedBox(height: 8),
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: options.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final opt = entry.value;
                      final isCorrectOption = idx == correctIdx;
                      final isUserChoice = idx == userAnswer;

                      Color bgColor = Colors.grey[200]!;
                      if (isCorrectOption) {
                        bgColor = Colors.green[100]!;
                      } else if (isUserChoice && !isCorrect) {
                        bgColor = Colors.red[100]!;
                      }

                      return Chip(
                        label: Text(
                          '${String.fromCharCode(65 + idx)}. ${quizType == 'ch2en' ? opt.english : opt.chinese}',
                          style: TextStyle(
                            color: isCorrectOption
                                ? Colors.green[800]
                                : (isUserChoice ? Colors.red[800] : null),
                            fontWeight: isCorrectOption || isUserChoice
                                ? FontWeight.bold
                                : null,
                          ),
                        ),
                        backgroundColor: bgColor,
                        side: BorderSide(
                          color: isCorrectOption
                              ? Colors.green[300]!
                              : (isUserChoice
                                  ? Colors.red[300]!
                                  : Colors.grey[300]!),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum SortOrder { az, level }

class AllWordsPage extends StatefulWidget {
  const AllWordsPage({super.key});

  @override
  State<AllWordsPage> createState() => _AllWordsPageState();
}

class _AllWordsPageState extends State<AllWordsPage> {
  late FlutterTts flutterTts;
  List<Word> _allWords = [];
  List<Word> _filteredWords = [];
  final TextEditingController _searchController = TextEditingController();
  SortOrder _sortOrder = SortOrder.az;

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    _initTts();
    _loadAllWords();
    _searchController.addListener(_filterWords);
  }

  Future<void> _initTts() async {
    final settings = SettingsProvider.of(context);
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(settings.speechRate);
    await flutterTts.setPitch(settings.speechPitch);
    await flutterTts.setVolume(settings.speechVolume);
    
    // Configure audio session to not pause background music
    await flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
      IosTextToSpeechAudioMode.spokenAudio,
    );
    
    if (settings.ttsVoice != null) {
      await flutterTts.setVoice(settings.ttsVoice!);
    }
  }

  Future<void> speakWord(String word) async {
    final textToSpeak = word.replaceAll('/', ' ');
    if (textToSpeak.trim().isEmpty) return;
    await _initTts(); // Re-initialize to apply latest settings
    await flutterTts.speak(textToSpeak);
  }

  Future<void> _loadAllWords() async {
    String data = await rootBundle.loadString('assets/words.json');
    List<dynamic> jsonResult = json.decode(data);
    setState(() {
      _allWords = jsonResult.map((item) => Word.fromJson(item)).toList();
      _filterAndSortWords();
    });
  }

  void _filterWords() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredWords = List.from(_allWords);
      });
    } else {
      setState(() {
        _filteredWords = _allWords
            .where(
              (word) =>
                  word.english.toLowerCase().contains(query) ||
                  word.chinese.contains(query),
            )
            .toList();
      });
    }
    _filterAndSortWords();
  }

  // New method to handle Enter key press
  void _onSearchSubmitted(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty && _filteredWords.isEmpty) {
      // Only show Cambridge dictionary dialog when Enter is pressed and no results found
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('找不到單字'),
          content: Text('找不到 "$trimmedQuery"，是否要在劍橋辭典中搜尋？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Use original query for dictionary search (preserve case for proper search)
                _launchURL(trimmedQuery);
              },
              child: const Text('前往劍橋辭典'),
            ),
          ],
        ),
      );
    }
  }

  void _filterAndSortWords() {
    List<Word> tempWords = List.from(_allWords);
    final query = _searchController.text.toLowerCase().trim();

    // First, filter the words based on the search query
    if (query.isNotEmpty) {
      tempWords = tempWords
          .where((word) => 
              word.english.toLowerCase().contains(query) ||
              word.chinese.contains(query))
          .toList();

      // For search results, sort by relevance
      tempWords.sort((a, b) {
        String aLower = a.english.toLowerCase();
        String bLower = b.english.toLowerCase();
        String aChinese = a.chinese;
        String bChinese = b.chinese;

        // Check if query matches English or Chinese
        bool aEnglishMatch = aLower.contains(query);
        bool bEnglishMatch = bLower.contains(query);

        // Exact English match gets highest priority
        bool aExactEnglish = aLower == query;
        bool bExactEnglish = bLower == query;
        if (aExactEnglish && !bExactEnglish) return -1;
        if (!aExactEnglish && bExactEnglish) return 1;

        // Exact Chinese match gets second priority
        bool aExactChinese = aChinese == query;
        bool bExactChinese = bChinese == query;
        if (aExactChinese && !bExactChinese) return -1;
        if (!aExactChinese && bExactChinese) return 1;

        // English starts with query gets third priority
        bool aStartsEnglish = aLower.startsWith(query);
        bool bStartsEnglish = bLower.startsWith(query);
        if (aStartsEnglish && !bStartsEnglish) return -1;
        if (!aStartsEnglish && bStartsEnglish) return 1;

        // Chinese starts with query gets fourth priority
        bool aStartsChinese = aChinese.startsWith(query);
        bool bStartsChinese = bChinese.startsWith(query);
        if (aStartsChinese && !bStartsChinese) return -1;
        if (!aStartsChinese && bStartsChinese) return 1;

        // If both have same type of match, prefer English matches
        if (aEnglishMatch && !bEnglishMatch) return -1;
        if (!aEnglishMatch && bEnglishMatch) return 1;

        // For words with same relevance, sort alphabetically by English
        return aLower.compareTo(bLower);
      });
    } else {
      // When no search query, sort based on the selected sort order
      if (_sortOrder == SortOrder.az) {
        tempWords.sort((a, b) {
          // Primary sort: first letter of English word
          int firstLetterComp = a.english[0].toLowerCase().compareTo(
                b.english[0].toLowerCase(),
              );
          if (firstLetterComp != 0) return firstLetterComp;

          // Secondary sort: word length (shorter words first)
          int lengthComp = a.english.length.compareTo(b.english.length);
          if (lengthComp != 0) return lengthComp;

          // Tertiary sort: alphabetical order for same length words
          return a.english.toLowerCase().compareTo(b.english.toLowerCase());
        });
      } else if (_sortOrder == SortOrder.level) {
        tempWords.sort((a, b) {
          // Primary sort: level (1 to 6)
          int levelComp = int.parse(a.level).compareTo(int.parse(b.level));
          if (levelComp != 0) return levelComp;

          // Secondary sort: alphabetical order within same level
          return a.english.toLowerCase().compareTo(b.english.toLowerCase());
        });
      }
    }

    setState(() {
      _filteredWords = tempWords;
    });
  }

  Future<void> _launchURL(String word) async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DictionaryWebView(word: word, isEnglishOnly: false),
        ),
      );
      await AppUtils.triggerHapticFeedback();
    } catch (e) {
      if (mounted) AppUtils.showErrorSnackBar(context, '發生錯誤: $e');
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('所有單字')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '搜尋單字',
                hintText: '輸入英文或中文後按 Enter 搜尋',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: _onSearchSubmitted,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('A-Z 排序'),
                  selected: _sortOrder == SortOrder.az,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _sortOrder = SortOrder.az;
                        _filterAndSortWords();
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('等級排序'),
                  selected: _sortOrder == SortOrder.level,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _sortOrder = SortOrder.level;
                        _filterAndSortWords();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredWords.length,
              itemBuilder: (context, index) {
                final word = _filteredWords[index];
                // Get the first part before "/" for dictionary lookup
                final lookupWord = word.english.split('/').first.trim();

                return ListTile(
                  title: Text(word.english),
                  subtitle: Text('等級 ${word.level} - ${word.chinese}'),
                  onTap: () {
                    speakWord(word.english);
                  },
                  onLongPress: () {
                    _launchURL(lookupWord);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.grey),
                    onPressed: () => speakWord(word.english),
                    tooltip: '發音',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WordCard extends StatefulWidget {
  final String word;
  const WordCard({super.key, required this.word});

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> {
  bool _isPressed = false;
  Timer? _longPressTimer;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (mounted) {
      setState(() => _isPressed = true);
    }

    _longPressTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      // 1. 震動
      await AppUtils.triggerHapticFeedback();

      // 2. 開啟字典 WebView
      try {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DictionaryWebView(word: widget.word, isEnglishOnly: false),
          ),
        );
      } catch (e) {
        if (mounted) AppUtils.showErrorSnackBar(context, '開啟字典時發生錯誤: $e');
      }
    });
  }

  void _onTapUp(TapUpDetails details) {
    _longPressTimer?.cancel();
    if (mounted) {
      setState(() => _isPressed = false);
    }
  }

  void _onTapCancel() {
    _longPressTimer?.cancel();
    if (mounted) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform:
            _isPressed ? (Matrix4.identity()..scale(0.95)) : Matrix4.identity(),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(widget.word, style: const TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }
}
