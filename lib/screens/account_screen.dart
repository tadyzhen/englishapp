import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Google Sign-In will be handled through Firebase Auth
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'modern_login_screen.dart';
import '../main.dart' show SettingsDialog;

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  User? _user;
  bool _isGuest = true;
  bool _isLoadingProfile = true;
  String? _displayName;
  String? _bio;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user?.isAnonymous ?? true;
    String? name;
    String? bio;

    if (user != null && !isGuest) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data() ?? {};
        name = (data['displayName'] as String?)?.trim();
        bio = (data['bio'] as String?)?.trim();
      } catch (_) {
        // ignore, fallback below
      }
      name ??= user.displayName;
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _isGuest = isGuest;
      _displayName = (name != null && name.isNotEmpty)
          ? name
          : (user?.email ?? '訪客用戶');
      _bio = bio;
      _isLoadingProfile = false;
    });
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Also sign out from Google provider if available
      try {
        final google = GoogleSignIn();
        await google.signOut();
      } catch (_) {}
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('login_method');
      await prefs.remove('is_guest');

      if (!context.mounted) return;
      // Reset navigation stack to login screen; AuthWrapper will also pick up auth change
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ModernLoginScreen(
            onLoginSuccess: () async {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登出失敗，請稍後再試')),
        );
      }
    }
  }

  Future<void> _editProfile(BuildContext context) async {
    if (_isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('訪客模式無法編輯個人資料，請先登入帳號')),
      );
      return;
    }
    final user = _user;
    if (user == null) return;

    final nameController = TextEditingController(text: _displayName ?? '');
    final bioController = TextEditingController(text: _bio ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('編輯個人資料'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '暱稱',
                    hintText: '顯示給好友與班級的名字',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bioController,
                  decoration: const InputDecoration(
                    labelText: '簡介',
                    hintText: '可以簡單介紹自己或學習目標',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final newName = nameController.text.trim();
    final newBio = bioController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暱稱不能為空白')),
      );
      return;
    }

    try {
      // 更新 Firebase Auth displayName
      await user.updateDisplayName(newName);
      // 更新 Firestore 使用者文件
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'displayName': newName,
          'bio': newBio,
          'lastLogin': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      setState(() {
        _displayName = newName;
        _bio = newBio.isEmpty ? null : newBio;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已更新個人資料')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新失敗，請稍後再試')),
      );
    }
  }

  Future<void> _showFeedbackDialog(BuildContext context) async {
    final feedbackController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('意見回饋'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '請輸入您的意見或建議，我們會盡快回覆您。',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: feedbackController,
                  decoration: const InputDecoration(
                    labelText: '意見內容',
                    hintText: '請輸入您的意見或建議...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 6,
                  minLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (feedbackController.text.trim().isNotEmpty) {
                  Navigator.of(ctx).pop(true);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('請輸入意見內容')),
                  );
                }
              },
              child: const Text('發送'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final feedback = feedbackController.text.trim();
    if (feedback.isEmpty) return;

    try {
      final email = Uri.encodeComponent('tady0857@gmail.com');
      final subject = Uri.encodeComponent('應用程式意見回饋');
      final body = Uri.encodeComponent(feedback);
      final mailtoUri = 'mailto:$email?subject=$subject&body=$body';

      final uri = Uri.parse(mailtoUri);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已開啟郵件應用程式')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法開啟郵件應用程式')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('發送失敗: $e')),
      );
    }
  }

  Future<void> _showAuthorInfo(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person, color: Colors.blue),
              SizedBox(width: 8),
              Text('作者介紹'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              SizedBox(height: 16),
              Text(
                '霸道總裁陳泰綻老闆',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                '感謝您使用本應用程式！',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final isGuest = _isGuest;

    return Scaffold(
      appBar: AppBar(
        title: const Text('帳號設定'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue[100],
            backgroundImage: (!isGuest && user?.photoURL != null)
                ? NetworkImage(user!.photoURL!)
                : null,
            child: (!isGuest && user?.photoURL != null)
                ? null
                : Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.blue[800],
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            _isLoadingProfile
                ? '載入中...'
                : (_displayName ?? (user?.email ?? '訪客用戶')),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isGuest ? '訪客模式' : '已登入',
            style: TextStyle(
              color: isGuest ? Colors.orange : Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_bio != null && _bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _bio!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (!isGuest) ...[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('編輯個人資料'),
              subtitle: const Text('修改暱稱與個人簡介'),
              trailing: const Icon(Icons.edit, size: 18),
              onTap: () => _editProfile(context),
            ),
            const Divider(),
          ],
          if (isGuest) ...[
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('登入 / 註冊'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to login screen and remove all previous routes
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => ModernLoginScreen(
                    onLoginSuccess: () async {
                      // After login, pop the login screen to return to the account screen.
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  )),
                  (route) => false,
                );
              },
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('應用程式設定'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => const SettingsDialog(),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('意見回饋'),
            subtitle: const Text('提供您的寶貴意見'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showFeedbackDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('作者介紹'),
            subtitle: const Text('關於開發者'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showAuthorInfo(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('幫助與支援'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Show help and support
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隱私權政策'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Show privacy policy
            },
          ),
          const Divider(),
          if (!isGuest) ...[
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('登出', style: TextStyle(color: Colors.red)),
              onTap: () => _signOut(context),
            ),
            const Divider(),
          ],
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '版本 1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
