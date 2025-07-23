import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'firebase_options.dart';
import 'dictionary_webview.dart';
import 'screens/login_screen.dart';
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
  Map<String, String>? ttsVoice;

  AppSettings({
    required this.themeMode,
    this.autoSpeak = false,
    this.speechRate = 0.4,
    this.speechPitch = 1.0,
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

  void _refreshAuthState() {
    // Force a rebuild to check current auth state
    if (mounted) {
      setState(() {
        _isLoading = false; // Don't show loading, just refresh
      });
    }
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

    // Handle guest mode
    if (_loginMethod == 'guest') {
      return const MainNavigation();
    }

    // Handle authenticated users
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

        // User is authenticated
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavigation();
        }

        // Check if we have a valid login method but user is null (edge case)
        if (_loginMethod == 'google' || _loginMethod == 'email') {
          // Give Firebase a moment to update auth state
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在登入...'),
                ],
              ),
            ),
          );
        }

        // User is not authenticated - show login screen
        return LoginScreen(
          onLoginSuccess: () {
            // Refresh the auth state after successful login
            _refreshAuthState();
          },
        );
      },
    );
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

  Future<void> resetAllProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('確定要重置所有進度嗎？'),
        content: const Text('這將清除所有熟知記錄，且無法復原。'),
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
      if (mounted) {
        setState(() {
          isResetting = false;
        });
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
              content: const Text('所有熟知記錄已重置'),
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
    final favs = prefs.getStringList('favorite_words') ?? [];
    String data = await rootBundle.loadString('assets/words.json');
    List<dynamic> jsonResult = json.decode(data);
    List<Word> allWords = jsonResult
        .map((item) => Word.fromJson(item))
        .toList();
    setState(() {
      favoriteWords = allWords.where((w) => favs.contains(w.english)).toList();
    });
  }

  void showSettingsDialog() {
    showDialog(context: context, builder: (ctx) => const SettingsDialog());
  }

  Future<void> _showLevelOptionsDialog(
    String level, {
    required bool hasProgress,
  }) async {
    final words = await _loadWordsForLevel(level);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('等級 $level'),
        content: const Text('請選擇一個選項'),
        actions: [
          TextButton(
            child: const Text('選擇單字'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WordListPage(level: level, words: words),
                ),
              );
            },
          ),
          TextButton(
            child: Text(hasProgress ? '繼續' : '開始'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WordQuizPage(initialLevel: level),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 取得指定等級的單字數量
  Future<int> _getWordCountForLevel(String level) async {
    try {
      String data = await rootBundle.loadString('assets/words.json');
      List<dynamic> jsonResult = json.decode(data);
      List<Word> words = jsonResult.map((item) => Word.fromJson(item)).toList();

      if (level == '全部') {
        return words.length;
      }
      return words.where((word) => word.level == level).length;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('載入單字時發生錯誤: $e')));
      }
      return 10; // Default to 10 questions if there's an error
    }
  }

  Future<void> _launchURL(String word) async {
    // Always use the part before "/" for dictionary lookup
    final cleanWord = word.split('/').first.trim();
    final url =
        'https://dictionary.cambridge.org/zht/%E8%A9%9E%E5%85%B8/%E8%8B%B1%E8%AA%9E-%E6%BC%A2%E8%AA%9E-%E7%B9%81%E9%AB%94/$cleanWord';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('無法開啟字典: $cleanWord')));
    }
  }

  Future<void> _showQuizOptions() async {
    final quizLevels = ['1', '2', '3', '4', '5', '6', '全部'];
    String? selectedLevel = '全部';
    int questionCount = 10;
    int maxQuestions = 10;
    String quizType = 'ch2en';
    final TextEditingController countController = TextEditingController(
      text: '10',
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('測驗設定'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 測驗等級選擇
                  const Text(
                    '1. 選擇測驗等級',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                            selectedLevel = level;
                            // 更新最大題數
                            maxQuestions = await _getWordCountForLevel(level);
                            if (questionCount > maxQuestions) {
                              questionCount = maxQuestions;
                              countController.text = questionCount.toString();
                            }
                            setState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 題數選擇
                  const Text(
                    '2. 選擇測驗題數',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: countController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            // Handle Enter key press
                            final count =
                                int.tryParse(countController.text) ?? 0;
                            if (count > 0 && count <= maxQuestions) {
                              questionCount = count;
                              Navigator.of(context).pop({
                                'level': selectedLevel,
                                'count': questionCount,
                                'type': quizType,
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '題數 (1-$maxQuestions)',
                            border: const OutlineInputBorder(),
                            hintText: '輸入後按 Enter 確認',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            final count = int.tryParse(value) ?? 0;
                            if (count > 0 && count <= maxQuestions) {
                              questionCount = count;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text('最多: $maxQuestions 題'),
                    ],
                  ),
                  Slider(
                    value: questionCount.toDouble(),
                    min: 1,
                    max: maxQuestions.toDouble(),
                    divisions: maxQuestions - 1,
                    label: questionCount.toString(),
                    onChanged: (value) {
                      questionCount = value.toInt();
                      countController.text = questionCount.toString();
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),

                  // 測驗模式選擇
                  const Text(
                    '3. 選擇測驗模式',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('題目顯示中文（選英文）'),
                        value: 'ch2en',
                        groupValue: quizType,
                        onChanged: (value) {
                          quizType = value!;
                          setState(() {});
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('題目顯示英文（選中文）'),
                        value: 'en2ch',
                        groupValue: quizType,
                        onChanged: (value) {
                          quizType = value!;
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedLevel != null) {
                    Navigator.pop(ctx, {
                      'level': selectedLevel,
                      'count': questionCount,
                      'type': quizType,
                    });
                  }
                },
                child: const Text('開始測驗'),
              ),
            ],
          );
        },
      ),
    ).then((result) async {
      if (result != null) {
        final level = result['level'] as String;
        final count = result['count'] as int;
        final type = result['type'] as String;

        // 檢查題數是否有效
        final wordCount = await _getWordCountForLevel(level);
        final finalCount = count > wordCount ? wordCount : count;

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                QuizPage(type: type, level: level, questionCount: finalCount),
          ),
        );
      }
    });
  }

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
    final double gridSpacing = 24;
    final Color mainButtonColor = Theme.of(context).colorScheme.primary;
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
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: showSettingsDialog,
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
            SizedBox(
              width: 300,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.quiz),
                label: const Text('測驗'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _showQuizOptions,
              ),
            ),
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
                      final prefs = await SharedPreferences.getInstance();
                      final knownWords =
                          prefs.getStringList('known_$level') ?? [];
                      final hasProgress = knownWords.isNotEmpty;
                      _showLevelOptionsDialog(level, hasProgress: hasProgress);
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
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '等級 $level',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : (Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color ??
                                        const Color(0xFF222222)),
                              letterSpacing: 1.2,
                            ),
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
  const WordQuizPage({super.key, this.initialLevel, this.initialWordIndex});
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
  DateTime? _pressStartTime;

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
    List<Word> wordList = List<Word>.from(temp[level] ?? []);
    Set<String> known = prefs.getStringList('known_$level')?.toSet() ?? {};
    Set<String> favs = prefs.getStringList('favorite_words')?.toSet() ?? {};

    int firstUnfamiliar = -1;
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

    setState(() {
      levelWords = temp;
      selectedLevel = level;
      words = wordList;
      knownWords = known;
      favoriteWords = favs;
      knownCount = known.length;
      currentIndex = firstUnfamiliar;
      isFinished = known.length >= words.length;
      showChinese = false;
      isLoading = false;
    });

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

  int _findPreviousUnfamiliarIndex(int fromIndex) {
    for (int i = fromIndex - 1; i >= 0; i--) {
      if (!knownWords.contains(words[i].english)) {
        return i;
      }
    }
    return -1; // No previous unfamiliar words
  }

  Future<void> handleSwipe(bool known) async {
    if (isFinished) return;
    final prefs = await SharedPreferences.getInstance();
    String key = 'known_${selectedLevel ?? ''}';
    String wordKey = words[currentIndex].english;

    // Update known words set based on swipe direction
    if (known) {
      knownWords.add(wordKey);
    } else {
      knownWords.remove(wordKey);
    }
    // Save updated known words to shared preferences
    await prefs.setStringList(key, knownWords.toList());

    final nextIndex = _findNextUnfamiliarIndex(currentIndex);

    setState(() {
      // Always update knownCount to reflect current knownWords size
      knownCount = knownWords.length;
      if (nextIndex != -1) {
        currentIndex = nextIndex;
        showChinese = false;
      } else {
        isFinished = true;
      }
    });

    final settings = SettingsProvider.of(context);
    if (settings.autoSpeak && !isFinished && currentIndex < words.length) {
      await Future.delayed(const Duration(milliseconds: 300));
      speakWord(words[currentIndex].english);
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
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已加入收藏')));
    }
    setState(() {});
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
                  '$knownCount / ${words.length}  (${(progress * 100).toStringAsFixed(1)}%)',
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
            child: isFinished
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Color(0xFFFFC700),
                        size: 100,
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        '恭喜你完成本等級所有單字！',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '熟知單字：$knownCount / ${words.length}',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: 180,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: progressColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            '返回等級選單',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
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
                      onLongPressStart: (_) {
                        setState(() => _isPressed = true);
                        HapticFeedback.lightImpact();
                        _pressStartTime = DateTime.now();
                      },
                      onLongPressEnd: (_) {
                        if (_pressStartTime != null) {
                          final pressDuration = DateTime.now().difference(
                            _pressStartTime!,
                          );
                          setState(() => _isPressed = false);

                          if (pressDuration > const Duration(seconds: 1)) {
                            _openDictionary();
                          } else {
                            setState(() => showChinese = !showChinese);
                          }
                        } else {
                          setState(() => _isPressed = false);
                        }
                      },
                      onLongPressCancel: () {
                        setState(() => _isPressed = false);
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
                              color:
                                  Theme.of(context).brightness ==
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
                                color:
                                    Theme.of(context).brightness ==
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
                                          color:
                                              Theme.of(context).brightness ==
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
                                    color:
                                        Theme.of(context).brightness ==
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

class WordListPage extends StatelessWidget {
  final String level;
  final List<Word> words;

  const WordListPage({super.key, required this.level, required this.words});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('等級 $level - 單字列表')),
      body: ListView.builder(
        itemCount: words.length,
        itemBuilder: (context, index) {
          final word = words[index];
          return ListTile(
            title: Text(word.english),
            subtitle: Text(word.chinese),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => WordQuizPage(
                    initialLevel: level,
                    initialWordIndex: index,
                  ),
                ),
              );
            },
          );
        },
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
  final String level;
  final int questionCount;
  const QuizPage({
    super.key,
    required this.type,
    required this.level,
    this.questionCount = 10, // Default to 10 if not specified
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
    _resetQuiz();
  }

  Future<void> _resetQuiz() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('確定要重新開始測驗嗎？'),
        content: const Text('這將清除目前的測驗進度。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        setState(() {
          _showAnswer = false;
          _isAnswerCorrect = false;
          _selectedIndex = null;
          _showAllTranslations = false;
        });
        loadQuiz();
      }
    }
  }

  Future<void> loadQuiz() async {
    String data = await rootBundle.loadString('assets/words.json');
    List<dynamic> jsonResult = json.decode(data);
    allWords = jsonResult.map((item) => Word.fromJson(item)).toList();

    List<Word> filteredWords;
    if (widget.level == '全部') {
      filteredWords = List.from(allWords);
    } else {
      filteredWords = allWords.where((w) => w.level == widget.level).toList();
    }

    // Only shuffle and take new questions if we're not restoring state
    if (quizWords.isEmpty) {
      filteredWords.shuffle();
      final count = widget.questionCount > filteredWords.length
          ? filteredWords.length
          : widget.questionCount;
      quizWords = filteredWords.take(count).toList();
    }

    // 預先產生每題的選項
    optionsList = quizWords.map((answer) {
      List<Word> options = [answer];
      List<Word> pool = allWords
          .where((w) => w.english != answer.english)
          .toList();
      pool.shuffle();
      while (options.length < 4 && pool.isNotEmpty) {
        options.add(pool.removeLast());
      }
      options.shuffle();
      return options;
    }).toList();

    // Initialize userAnswers if not already done
    if (userAnswers.length != quizWords.length) {
      userAnswers = List.filled(quizWords.length, -1);
    }

    if (mounted) {
      setState(() {
        current = 0;
        score = userAnswers
            .where((ans) => ans != -1)
            .length; // Count already answered questions
      });
    }
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

      // Update the answer in our tracking
      if (userAnswers[current] == -1) {
        // Only update if not already answered
        if (_isAnswerCorrect) {
          score++;
        }
        userAnswers[current] = selectedIndex;
      }

      if (_isAnswerCorrect) {
        _showAllTranslations = false;
        // Auto-advance to next question after a short delay if answer is correct
        Future.delayed(const Duration(milliseconds: 500), _nextQuestion);
      } else {
        _showAllTranslations =
            true; // Show all translations for incorrect answers
      }
    });
  }

  void _previousQuestion() {
    if (current > 0) {
      setState(() {
        current--;
        // When going back, show the answer state if it was already answered
        _showAnswer = userAnswers[current] != -1;
        _selectedIndex = userAnswers[current] != -1
            ? userAnswers[current]
            : null;
        _isProcessing = false;
        // Show translations if this question was answered incorrectly
        _showAllTranslations =
            _showAnswer &&
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已加入收藏')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (quizWords.isEmpty) {
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
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.3),
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
                                        color:
                                            isSelected &&
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
                  // Navigation buttons - moved up just below options
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

  @override
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
  List<Word> _allWords = [];
  List<Word> _filteredWords = [];
  final TextEditingController _searchController = TextEditingController();
  SortOrder _sortOrder = SortOrder.az;

  @override
  void initState() {
    super.initState();
    _loadAllWords();
    _searchController.addListener(_filterWords);
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
    final trimmedQuery = query.toLowerCase().trim();
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
    final query = _searchController.text.toLowerCase();

    // First, filter the words based on the search query
    if (query.isNotEmpty) {
      tempWords = tempWords
          .where((word) => word.english.toLowerCase().contains(query))
          .toList();

      // For search results, sort by relevance (exact match first, then starts with, then contains)
      tempWords.sort((a, b) {
        String aLower = a.english.toLowerCase();
        String bLower = b.english.toLowerCase();

        // Exact match gets highest priority
        bool aExact = aLower == query;
        bool bExact = bLower == query;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;

        // Words starting with query get second priority
        bool aStarts = aLower.startsWith(query);
        bool bStarts = bLower.startsWith(query);
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;

        // For words with same relevance, sort alphabetically
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
                hintText: '輸入單字後按 Enter 搜尋',
                prefixIcon: const Icon(Icons.search),
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
                bool isPressing = false;
                Timer? longPressTimer;

                return StatefulBuilder(
                  builder: (context, setState) {
                    return GestureDetector(
                      onTapDown: (_) {
                        setState(() => isPressing = true);
                        // Stronger haptic feedback
                        HapticFeedback.heavyImpact();

                        // Set timer for dictionary launch (0.5s)
                        longPressTimer = Timer(
                          const Duration(milliseconds: 500),
                          () {
                            if (mounted) {
                              _launchURL(lookupWord);
                            }
                          },
                        );
                      },
                      onTapUp: (_) {
                        longPressTimer?.cancel();
                        if (mounted) {
                          setState(() => isPressing = false);
                        }
                      },
                      onTapCancel: () {
                        longPressTimer?.cancel();
                        if (mounted) {
                          setState(() => isPressing = false);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 50),
                        color: isPressing ? Colors.grey[200] : null,
                        child: ListTile(
                          title: Text(word.english),
                          subtitle: Text('等級 ${word.level} - ${word.chinese}'),
                          trailing: const Icon(
                            Icons.launch,
                            size: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    );
                  },
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
  double _scale = 1.0;
  Timer? _holdTimer;

  void _onTapDown(TapDownDetails details) {
    setState(() => _scale = 0.95);
    AppUtils.triggerHapticFeedback();

    _holdTimer = Timer(const Duration(milliseconds: 500), () {
      _navigateToCambridge();
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
    _holdTimer?.cancel();
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
    _holdTimer?.cancel();
  }

  void _navigateToCambridge() {
    final url =
        'https://dictionary.cambridge.org/dictionary/english/\${widget.word}';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _scale,
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
