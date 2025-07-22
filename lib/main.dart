import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math' as math;

// ========== AppSettings 狀態管理 ==========
class AppSettings extends ChangeNotifier {
  ThemeMode themeMode;
  bool autoSpeak;
  AppSettings({required this.themeMode, this.autoSpeak = false});

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

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    String theme = prefs.getString('themeMode') ?? 'light';
    bool autoSpeak = prefs.getBool('autoSpeak') ?? false;
    return AppSettings(
      themeMode: theme == 'dark' ? ThemeMode.dark : ThemeMode.light,
      autoSpeak: autoSpeak,
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
    final settings = SettingsProvider.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '設定',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 主題切換
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('主題模式', style: TextStyle(fontSize: 18)),
                  DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('亮'),
                      ),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('暗')),
                    ],
                    onChanged: (mode) {
                      if (mode != null) settings.setThemeMode(mode);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 自動播放語音
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                '關閉',
                style: TextStyle(color: Color(0xFF007AFF)),
              ),
            ),
          ],
        );
      },
    );
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
                onPressed: () async {
                  // 題型選擇
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
                      MaterialPageRoute(builder: (_) => QuizPage(type: type)),
                    );
                  }
                },
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WordQuizPage(initialLevel: level),
                        ),
                      );
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

class Word {
  final String level;
  final String english;
  final String pos;
  final String engPos;
  final String chinese;

  Word({
    required this.level,
    required this.english,
    required this.pos,
    required this.engPos,
    required this.chinese,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      level: json['level'].toString(),
      english: json['word'].toString(),
      pos: json['pos'].toString(),
      engPos: json['output'].toString(),
      chinese: json['chinese'].toString(),
    );
  }
}

class WordQuizPage extends StatefulWidget {
  final String? initialLevel;
  const WordQuizPage({super.key, this.initialLevel});
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

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    _initTts();
    loadWordsAndProgress();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.4);
    setTtsVoice();
    setState(() {
      ttsReady = true;
    });

    // 新增語音結束監聽
    flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
    flutterTts.setCancelHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  void setTtsVoice() async {
    // 只選用美式英語 en-US 第一個 voice
    List voicesRaw = await flutterTts.getVoices;
    final voices = voicesRaw.where((v) => v['locale'] == 'en-US').toList();
    if (voices.isNotEmpty) {
      final voice = voices[0];
      await flutterTts.setVoice({
        "name": voice['name'],
        "locale": voice['locale'],
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setTtsVoice();
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  Future<void> speakWord(String word) async {
    if (isSpeaking) return;
    // 如果單字包含 /，不發音
    if (word.contains('/')) {
      return;
    }
    setState(() {
      isSpeaking = true;
    });
    try {
      await flutterTts.stop();
      setTtsVoice();
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // 避免 stop/speak 太快破音
      await flutterTts.speak(word);
    } catch (e) {
      setState(() {
        isSpeaking = false;
      });
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
    int firstUnfamiliar = 0;
    for (int i = 0; i < wordList.length; i++) {
      if (!known.contains(wordList[i].english)) {
        firstUnfamiliar = i;
        break;
      }
      if (i == wordList.length - 1) firstUnfamiliar = wordList.length;
    }
    setState(() {
      levelWords = temp;
      selectedLevel = level;
      words = wordList;
      knownWords = known;
      favoriteWords = favs;
      knownCount = known.length;
      currentIndex = firstUnfamiliar < wordList.length ? firstUnfamiliar : 0;
      isFinished = known.length >= words.length;
      showChinese = false;
      isLoading = false;
    });
    // 自動播放語音
    final settings = SettingsProvider.of(context);
    if (settings.autoSpeak && words.isNotEmpty && !isFinished) {
      await Future.delayed(const Duration(milliseconds: 300));
      speakWord(words[currentIndex].english);
    }
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
    setState(() {
      if (known) knownCount = knownWords.length;
      if (currentIndex < words.length - 1) {
        currentIndex++;
        showChinese = false;
      } else {
        isFinished = knownWords.length >= words.length;
      }
    });
    // 自動播放語音
    final settings = SettingsProvider.of(context);
    if (settings.autoSpeak && !isFinished && currentIndex < words.length) {
      await Future.delayed(const Duration(milliseconds: 300));
      speakWord(words[currentIndex].english);
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
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
                        child: Stack(
                          children: [
                            // 星星圖案
                            if (favoriteWords.contains(
                              words[currentIndex].english,
                            ))
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 36,
                                ),
                              ),
                            // 單字內容
                            Column(
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
                          ],
                        ),
                      ),
                    ),
                  ),
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
  const QuizPage({super.key, required this.type});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<Word> allWords = [];
  List<Word> quizWords = [];
  int current = 0;
  int score = 0;
  List<int> userAnswers = [];
  bool showResult = false;
  List<List<Word>> optionsList = [];

  @override
  void initState() {
    super.initState();
    loadQuiz();
  }

  Future<void> loadQuiz() async {
    String data = await rootBundle.loadString('assets/words.json');
    List<dynamic> jsonResult = json.decode(data);
    allWords = jsonResult.map((item) => Word.fromJson(item)).toList();
    allWords.shuffle();
    quizWords = allWords.take(10).toList();
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
      showResult = false;
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
    if (showResult) {
      return Scaffold(
        appBar: AppBar(title: const Text('測驗結果')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '分數：$score / 10',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回主畫面'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => loadQuiz(),
                child: const Text('再測一次'),
              ),
            ],
          ),
        ),
      );
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
                              : () {
                                  setState(() {
                                    userAnswers.add(i);
                                    if (i == correctIdx) score++;
                                  });
                                },
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
          if (answered)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: current > 0
                          ? () => setState(() => current--)
                          : null,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back),
                          SizedBox(width: 8),
                          Text('上一題'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: current < 9
                          ? () => setState(() => current++)
                          : () => setState(() => showResult = true),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(current < 9 ? '下一題' : '看分數'),
                          const SizedBox(width: 8),
                          Icon(
                            current < 9
                                ? Icons.arrow_forward
                                : Icons.emoji_events,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
