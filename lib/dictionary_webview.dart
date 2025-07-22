import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();

    // ✅ 安全處理單字（避免斜線、多字等造成錯誤）
    final original = widget.word.trim().toLowerCase();
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

  @override
  Widget build(BuildContext context) {
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
