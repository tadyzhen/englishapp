import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_screen.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Save login method
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('login_method', 'email');
      
      // Show success message and navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('登入成功！'),
            duration: Duration(seconds: 1),
          ),
        );
        
        // Navigate immediately
        widget.onLoginSuccess();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? '登入失敗，請稍後再試';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to create/update user profile in Firestore
  Future<void> _updateUserProfile(User user, {String? displayName, String? photoUrl}) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    
    await userDoc.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': displayName ?? user.displayName,
      'photoUrl': photoUrl ?? user.photoURL,
      'lastLogin': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _signInWithGoogle() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Sign out first to ensure a clean state
      await _googleSignIn.signOut();
      
      // Start the Google sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create a credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with credential
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user != null) {
        // Check if this is a new user
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
        
        // Update user profile in Firestore
        await _updateUserProfile(
          user,
          displayName: googleUser.displayName,
          photoUrl: googleUser.photoUrl,
        );
        
        // Save login method
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('login_method', 'google');
        
        if (mounted) {
          debugPrint('Google login successful. User: ${user.email}, isNewUser: $isNewUser');
          
          if (isNewUser) {
            // Show welcome message for new users
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('註冊成功！歡迎使用英文學習助手'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            // Show login success message for returning users
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('登入成功！'),
                duration: Duration(seconds: 1),
                backgroundColor: Colors.green,
              ),
            );
          }
          
          debugPrint('Calling onLoginSuccess callback');
          // Navigate immediately after showing message
          widget.onLoginSuccess();
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Google 登入失敗，請稍後再試';
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = '此電子郵件已經使用其他方式註冊';
      } else if (e.code == 'invalid-credential') {
        errorMessage = '無效的憑證，請重試';
      }
      setState(() => _errorMessage = errorMessage);
    } catch (e) {
      setState(() => _errorMessage = '發生錯誤，請稍後再試');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInAsGuest() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Sign out any existing user
      await FirebaseAuth.instance.signOut();
      
      // Save guest mode
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('login_method', 'guest');
      
      if (mounted) {
        debugPrint('Guest login successful, calling onLoginSuccess callback');
        
        // Show guest mode message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('訪客模式啟用'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.orange,
          ),
        );
        
        // Navigate immediately
        widget.onLoginSuccess();
      }
    } catch (e) {
      debugPrint('Guest login error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '無法以訪客身份登入，請稍後再試';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登入'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            // Emergency navigation back to main app
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainNavigation()),
              (route) => false,
            );
          },
          tooltip: '返回主頁',
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    const Text(
                      '英文學習助手',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 40),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '電子郵件',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入電子郵件';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: '密碼',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入密碼';
                  }
                  if (value.length < 6) {
                    return '密碼長度至少為6個字元';
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...{
                const SizedBox(height: 24),
              },
              ElevatedButton(
                onPressed: _isLoading ? null : _signInWithEmailAndPassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('登入'),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterScreen(
                              onRegisterSuccess: widget.onLoginSuccess,
                            ),
                          ),
                        );
                      },
                child: const Text('還沒有帳號？立即註冊'),
              ),
              const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        // TODO: 實現忘記密碼功能
                      },
                      child: const Text('忘記密碼？'),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Image.asset(
                          'assets/icons/google.png',
                          height: 20,
                          width: 20,
                        ),
                      ),
                      label: const Text('使用 Google 登入'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        side: const BorderSide(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // 將「暫不登入」按鈕放在底部
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _signInAsGuest,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                      child: const Text(
                        '暫不登入 (無法保存紀錄)',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
