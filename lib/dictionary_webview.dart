import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DictionaryWebView extends StatefulWidget {
  final String word;
  final bool isEnglishOnly;

  const DictionaryWebView({
    Key? key,
    required this.word,
    this.isEnglishOnly = false,
  }) : super(key: key);

  @override
  State<DictionaryWebView> createState() => _DictionaryWebViewState();
}

class _DictionaryWebViewState extends State<DictionaryWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _webUrlLaunched = false;

  @override
  void initState() {
    super.initState();

    // ✅ 安全處理單字（避免斜線、多字等造成錯誤）
    // ✅ 移除括號內容 (例如: enhancement(s) -> enhancement)
    final original =
        widget.word.trim().toLowerCase().replaceAll(RegExp(r'\(.*\)'), '');
    final lookupWord = switch (original) {
      'a/an' => 'a',
      'is/are' => 'is',
      'have/has' => 'have',
      _ => original.contains('/') ? original.split('/').first.trim() : original,
    };

    final encodedWord = Uri.encodeComponent(lookupWord);
    final url = widget.isEnglishOnly
        ? 'https://dictionary.cambridge.org/dictionary/english/$encodedWord'
        : 'https://dictionary.cambridge.org/dictionary/english-chinese-traditional/$encodedWord';

    // On web, Cambridge blocks being embedded in an iframe/WebView.
    // We'll handle the launch in build() method where we have access to MediaQuery
    if (kIsWeb) {
      // Store URL for later use in build method
      _webUrlLaunched = false;
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  void _launchWebUrl(String url) {
    if (_webUrlLaunched) return;
    _webUrlLaunched = true;

    final uri = Uri.parse(url);
    
    // Detect if running on mobile device by checking screen width
    // Mobile devices typically have screen width < 600px
    bool isMobile = false;
    try {
      final mediaQuery = MediaQuery.maybeOf(context);
      if (mediaQuery != null) {
        isMobile = mediaQuery.size.width < 600 || 
                   mediaQuery.size.shortestSide < 600;
      }
    } catch (_) {
      // Default to mobile if detection fails (safer for mobile browsers)
      isMobile = true;
    }
    
    // Launch URL asynchronously without blocking
    launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: isMobile ? '_self' : '_blank',
    ).then((_) {
      // Successfully opened, close this route
      // For mobile, this allows user to use browser back button to return
      // For desktop, new tab preserves the app state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }).catchError((e) {
      // If launch fails, show error and close the route
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法開啟網頁: $e')),
        );
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Handle web URL launch in build method where we have access to MediaQuery
    if (kIsWeb && !_webUrlLaunched) {
      final original =
          widget.word.trim().toLowerCase().replaceAll(RegExp(r'\(.*\)'), '');
      final lookupWord = switch (original) {
        'a/an' => 'a',
        'is/are' => 'is',
        'have/has' => 'have',
        _ => original.contains('/') ? original.split('/').first.trim() : original,
      };
      final encodedWord = Uri.encodeComponent(lookupWord);
      final url = widget.isEnglishOnly
          ? 'https://dictionary.cambridge.org/dictionary/english/$encodedWord'
          : 'https://dictionary.cambridge.org/dictionary/english-chinese-traditional/$encodedWord';
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _launchWebUrl(url);
      });
    }

    if (kIsWeb) {
      // Show loading indicator while launching URL
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.word),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.word),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
