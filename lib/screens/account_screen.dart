import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Google Sign-In will be handled through Firebase Auth
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'modern_login_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({Key? key}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user?.isAnonymous ?? true;

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
            !isGuest && user?.displayName != null && user!.displayName!.isNotEmpty
                ? user!.displayName!
                : (user?.email ?? '訪客用戶'),
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
          const SizedBox(height: 32),
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
              // TODO: Navigate to settings
            },
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
