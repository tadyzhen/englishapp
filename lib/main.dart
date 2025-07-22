import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'dictionary_webview.dart';

// Utility class for shared functionality
class AppUtils {
  // Show error message in a snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
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
  final settings = await AppSettings.load();
  runApp(SettingsProvider(notifier: settings, child: const EnglishApp()));
}

class EnglishApp extends StatelessWidget {
  const EnglishApp({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = SettingsProvider.of(context);
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'SF Pro Display',
            scaffoldBackgroundColor: Colors.white,
            colorScheme: ColorScheme.fromSwatch().copyWith(
              primary: const Color(0xFF007AFF),
              secondary: const Color(0xFF007AFF),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: Color(0xFF222222)),
              titleTextStyle: TextStyle(
                color: Color(0xFF222222),
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontFamily: 'SF Pro Display',
              ),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSwatch().copyWith(
              primary: const Color(0xFF007AFF),
              secondary: const Color(0xFF007AFF),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF181818),
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontFamily: 'SF Pro Display',
              ),
            ),
          ),
          themeMode: settings.themeMode,
          home: const LevelSelectPage(),
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
    setState(() {
      isResetting = true;
    });
    final prefs = await SharedPreferences.getInstance();
    for (var level in levels) {
      await prefs.remove('known_$level');
    }
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
    showDialog(
      context: context,
      builder: (ctx) => const SettingsDialog(),
    );
  }

  Future<void> _showLevelOptionsDialog(String level, {required bool hasProgress}) async {
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

  Future<void> _showQuizOptions() async {
    final quizLevels = ['1', '2', '3', '4', '5', '6', '全部'];
    final selectedLevel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('選擇測驗等級'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: quizLevels
                .map((level) => ListTile(
                      title: Text('等級 $level'),
                      onTap: () => Navigator.pop(ctx, level),
                    ))
                .toList(),
          ),
        ),
      ),
    );

    if (selectedLevel == null) return;

    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('選擇題型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('題目顯示中文（選英文）'),
              onTap: () => Navigator.pop(ctx, 'ch2en'),
            ),
            ListTile(
              title: const Text('題目顯示英文（選中文）'),
              onTap: () => Navigator.pop(ctx, 'en2ch'),
            ),
          ],
        ),
      ),
    );

    if (type != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => QuizPage(type: type, level: selectedLevel)),
      );
    }
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
                      final knownWords = prefs.getStringList('known_$level') ?? [];
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
          .map((v) =>
              {"name": v['name'] as String, "locale": v['locale'] as String})
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        '設定',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
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
                          final selectedVoiceMap = _displayVoices
                              .firstWhere((v) => v['name'] == name);
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
          child: const Text(
            '關閉',
            style: TextStyle(color: Color(0xFF007AFF)),
          ),
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
        MaterialPageRoute(
          builder: (context) => DictionaryWebView(word: word),
        ),
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
    if (known) {
      knownWords.add(wordKey);
      await prefs.setStringList(key, knownWords.toList());
    }

    final nextIndex = _findNextUnfamiliarIndex(currentIndex);

    setState(() {
      if (known) knownCount = knownWords.length;
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
    final prevIndex = _findPreviousUnfamiliarIndex(currentIndex);
    if (prevIndex != -1) {
      setState(() {
        currentIndex = prevIndex;
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
                          final pressDuration = DateTime.now().difference(_pressStartTime!);
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
                            transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 100,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
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
                                    Theme.of(context).brightness == Brightness.dark
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
                                favoriteWords.contains(words[currentIndex].english)
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 36,
                              ),
                              onPressed: () async {
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
      appBar: AppBar(
        title: Text('等級 $level - 單字列表'),
      ),
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
  const QuizPage({super.key, required this.type, required this.level});
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

  @override
  void initState() {
    super.initState();
    loadQuiz();
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
    filteredWords.shuffle();
    quizWords = filteredWords.take(10).toList();

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
    setState(() {
      current = 0;
      score = 0;
      userAnswers = [];
    });
  }

  void _handleAnswer(int selectedIndex) {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      userAnswers.add(selectedIndex);
      final correctIdx = optionsList[current].indexWhere((w) => w.english == quizWords[current].english);
      if (selectedIndex == correctIdx) {
        score++;
      }
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (current < quizWords.length - 1) {
        setState(() {
          current++;
          _isProcessing = false;
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
    });
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
    int? selected = userAnswers.length > current ? userAnswers[current] : null;
    bool answered = selected != null;
    int correctIdx = options.indexWhere((w) => w.english == word.english);

    return Scaffold(
      appBar: AppBar(title: Text('測驗 (${current + 1}/10)')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onDoubleTap: () async {
                      // 雙擊題目加入收藏
                      await addToFavoriteQuiz(word.english);
                    },
                    child: Text(
                      widget.type == 'ch2en' ? word.chinese : word.english,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
                        final isSelected = selected == i;
                        Color? cardColor = Theme.of(context).cardColor;
                        Color? borderColor = Colors.grey[300];
                        BoxShadow? boxShadow;

                        if (answered) {
                          if (isCorrect) {
                            cardColor = Colors.green[300];
                            borderColor = Colors.green;
                            boxShadow = BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            );
                          } else if (isSelected) {
                            cardColor = Colors.red[300];
                            borderColor = Colors.red;
                            boxShadow = BoxShadow(
                              color: Colors.red.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            );
                          }
                        }

                        return GestureDetector(
                          onTap: answered
                              ? null
                              : () => _handleAnswer(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor!, width: 2),
                              boxShadow: boxShadow != null ? [boxShadow] : [],
                            ),
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: Text(
                                        widget.type == 'ch2en'
                                            ? opt.english
                                            : opt.chinese,
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.black
                                              : Theme.of(
                                                  context,
                                                ).textTheme.bodyLarge?.color,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                                if (answered) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.type == 'ch2en'
                                        ? opt.chinese
                                        : opt.english,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: isSelected
                                          ? Colors.black87
                                          : Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.color,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
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
      final correctIdx = optionsList[i].indexWhere((w) => w.english == quizWords[i].english);
      if (userAnswers[i] == correctIdx) {
        score++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('測驗結果 - $score / ${quizWords.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          )
        ],
      ),
      body: ListView.builder(
        itemCount: quizWords.length,
        itemBuilder: (context, index) {
          final word = quizWords[index];
          final options = optionsList[index];
          final userAnswerIdx = userAnswers[index];
          final correctIdx = options.indexWhere((w) => w.english == word.english);
          final bool isCorrect = userAnswerIdx == correctIdx;

          return Card(
            margin: const EdgeInsets.all(8.0),
            color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Q${index + 1}: ${quizType == 'ch2en' ? word.chinese : word.english}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...options.map((opt) {
                    final optIdx = options.indexOf(opt);
                    final bool isSelected = optIdx == userAnswerIdx;
                    final bool isAnswer = optIdx == correctIdx;

                    IconData? icon;
                    Color? color;
                    if (isAnswer) {
                      icon = Icons.check_circle;
                      color = Colors.green;
                    } else if (isSelected && !isCorrect) {
                      icon = Icons.cancel;
                      color = Colors.red;
                    }

                    return ListTile(
                      leading: icon != null ? Icon(icon, color: color) : null,
                      title: Text(quizType == 'ch2en' ? opt.english : opt.chinese),
                      subtitle: Text(quizType == 'ch2en' ? opt.chinese : opt.english),
                    );
                  }).toList(),
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
    _filterAndSortWords();
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
          int firstLetterComp = a.english[0].toLowerCase().compareTo(b.english[0].toLowerCase());
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
          builder: (context) => DictionaryWebView(
            word: word,
            isEnglishOnly: false,
          ),
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
      appBar: AppBar(
        title: const Text('所有單字'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '搜尋單字',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
                return ListTile(
                  title: Text(word.english),
                  subtitle: Text('等級 ${word.level} - ${word.chinese}'),
                  onTap: () => _launchURL(word.english),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}