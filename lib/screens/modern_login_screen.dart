import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_screen.dart';

class ModernLoginScreen extends StatefulWidget {
  final Future<void> Function() onLoginSuccess;

  const ModernLoginScreen({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  _ModernLoginScreenState createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final GoogleSignIn _googleSignIn;
  
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  bool _isGoogleSignInAvailable = true;
  bool _obscurePassword = true;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeGoogleSignIn();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  void _initializeGoogleSignIn() {
    try {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: Platform.isIOS 
            ? '390579676069-t5pppt4gnveqeirbrjj3qsamftp1vveu.apps.googleusercontent.com'
            : null,
      );
      
      _googleSignIn.isSignedIn().then((isSignedIn) {
        if (mounted) {
          setState(() {
            _isGoogleSignInAvailable = true;
          });
        }
      }).catchError((error) {
        debugPrint('Google Sign-In availability check failed: $error');
        if (mounted) {
          setState(() {
            _isGoogleSignInAvailable = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Google Sign-In initialization failed: $e');
      if (mounted) {
        setState(() {
          _isGoogleSignInAvailable = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmailAndPassword() async {
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      HapticFeedback.lightImpact();
      
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('login_method', 'email');
      
      if (mounted) {
        _showSuccessMessage('登入成功！歡迎回來');
        await Future.delayed(const Duration(milliseconds: 800));
        await widget.onLoginSuccess();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        await _handleAuthException(e);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '發生未預期的錯誤，請稍後再試');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAuthException(FirebaseAuthException e) async {
    switch (e.code) {
      case 'user-not-found':
        await _navigateToRegistration(
          '此電子郵件尚未註冊，為您導向註冊頁面',
          prefillEmail: true,
        );
        break;
      case 'wrong-password':
        // Check if this email might be registered with Google
        await _checkIfEmailRegisteredWithGoogle(_emailController.text.trim());
        break;
      case 'invalid-email':
        setState(() => _errorMessage = '請輸入有效的電子郵件格式');
        break;
      case 'user-disabled':
        setState(() => _errorMessage = '此帳號已被停用，請聯絡管理員');
        break;
      case 'too-many-requests':
        setState(() => _errorMessage = '登入嘗試次數過多，請稍後再試');
        break;
      case 'network-request-failed':
        setState(() => _errorMessage = '網路連線失敗，請檢查網路後重試');
        break;
      default:
        setState(() => _errorMessage = '登入失敗：${e.message ?? "未知錯誤"}');
    }
  }

  Future<void> _checkIfEmailRegisteredWithGoogle(String email) async {
    try {
      // Try to fetch sign-in methods for this email
      final signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      
      if (signInMethods.contains('google.com')) {
        setState(() {
          _errorMessage = '此電子郵件已使用 Google 帳號註冊，請使用 Google 登入';
        });
        _passwordController.clear();
        
        // Show info message with suggestion
        _showInfoMessage('建議您點擊下方的 "使用 Google 登入" 按鈕');
      } else {
        setState(() => _errorMessage = '密碼錯誤，請檢查後重試');
        _passwordController.clear();
      }
    } catch (e) {
      // If we can't check, just show generic password error
      setState(() => _errorMessage = '密碼錯誤，請檢查後重試');
      _passwordController.clear();
    }
  }

  Future<void> _continueAsGuest() async {
    // Prevent multiple calls
    if (_isLoading || _isGoogleLoading) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      HapticFeedback.lightImpact();
      
      // Save guest mode preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('login_method', 'guest');
      await prefs.setBool('is_guest', true);
      
      if (mounted) {
        _showSuccessMessage('以訪客模式進入應用程式');
        await Future.delayed(const Duration(milliseconds: 800));
        
        // Ensure we only call onLoginSuccess once
        if (mounted && _isLoading) {
          await widget.onLoginSuccess();
        }
      }
    } catch (e) {
      debugPrint('Guest mode error: $e');
      if (mounted) {
        setState(() => _errorMessage = '訪客模式啟動失敗，請稍後再試');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateToRegistration(String message, {bool prefillEmail = false}) async {
    _showInfoMessage(message);
    
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (mounted) {
      final result = await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => RegisterScreen(
            onRegisterSuccess: widget.onLoginSuccess,
            prefillEmail: prefillEmail ? _emailController.text.trim() : null,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      
      if (result == true) {
        return;
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!_isGoogleSignInAvailable) {
      setState(() {
        _errorMessage = 'Google 登入服務暫時無法使用，請使用電子郵件登入';
      });
      return;
    }

    // Prevent multiple calls
    if (_isLoading || _isGoogleLoading) {
      return;
    }

    try {
      setState(() {
        _isGoogleLoading = true;
        _errorMessage = null;
      });

      FocusScope.of(context).unfocus();
      HapticFeedback.lightImpact();
      
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Sign out error (non-critical): $e');
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Google 登入超時，請重試', const Duration(seconds: 30));
            },
          );
          
      if (googleUser == null) {
        if (mounted) {
          setState(() {
            _isGoogleLoading = false;
            _errorMessage = null;
          });
        }
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Google authentication tokens are invalid',
        );
      }
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user != null) {
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
        
        await _updateUserProfile(
          user,
          displayName: googleUser.displayName,
          photoUrl: googleUser.photoUrl,
        );
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('login_method', 'google');
        
        if (mounted) {
          debugPrint('Google login successful. User: ${user.email}, isNewUser: $isNewUser');
          
          if (isNewUser) {
            _showSuccessMessage('註冊成功！歡迎使用英文學習助手');
          } else {
            _showSuccessMessage('Google 登入成功！歡迎回來');
          }
          
          await Future.delayed(const Duration(milliseconds: 800));
          await widget.onLoginSuccess();
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('Google Sign-In timeout: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Google 登入超時，請檢查網路連線後重試');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth error: ${e.code} - ${e.message}');
      String errorMessage = 'Google 登入失敗，請稍後再試';
      
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = '此電子郵件已經使用其他方式註冊，請使用電子郵件登入';
          break;
        case 'invalid-credential':
          errorMessage = '無效的憑證，請重新嘗試 Google 登入';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Google 登入功能已被停用，請聯絡管理員';
          break;
        case 'user-disabled':
          errorMessage = '您的帳號已被停用，請聯絡管理員';
          break;
        case 'network-request-failed':
          errorMessage = '網路連線失敗，請檢查網路連線後重試';
          break;
        default:
          errorMessage = 'Google 登入失敗：${e.message ?? "未知錯誤"}';
      }
      
      if (mounted) {
        setState(() {
           _errorMessage = errorMessage;
           _isGoogleLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Unexpected Google Sign-In error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '發生未預期的錯誤，請稍後再試或使用電子郵件登入';
          _isGoogleLoading = false;
        });
      }
    } finally {
      if (mounted && _isGoogleLoading) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

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

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.indigo.shade100,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    _buildHeader(),
                    const SizedBox(height: 48),
                    _buildLoginForm(),
                    const SizedBox(height: 24),
                    _buildDivider(),
                    const SizedBox(height: 24),
                    if (_isGoogleSignInAvailable) _buildGoogleSignInButton(),
                    const SizedBox(height: 32),
                    _buildRegisterPrompt(),
                    const SizedBox(height: 24),
                    _buildGuestModeButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.school,
            size: 48,
            color: Colors.blue.shade600,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '英文學習助手',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '歡迎回來！請登入您的帳號',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEmailField(),
            const SizedBox(height: 20),
            _buildPasswordField(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorMessage(),
            ],
            const SizedBox(height: 32),
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: '電子郵件',
        hintText: '請輸入您的電子郵件',
        prefixIcon: Icon(Icons.email_outlined, color: Colors.blue.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      enabled: !_isLoading && !_isGoogleLoading,
      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '請輸入電子郵件';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return '請輸入有效的電子郵件格式';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: '密碼',
        hintText: '請輸入您的密碼',
        prefixIcon: Icon(Icons.lock_outlined, color: Colors.blue.shade600),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.grey.shade600,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      enabled: !_isLoading && !_isGoogleLoading,
      onFieldSubmitted: (_) {
        if (!_isLoading && !_isGoogleLoading) {
          _signInWithEmailAndPassword();
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '請輸入密碼';
        }
        if (value.length < 6) {
          return '密碼長度至少為6個字元';
        }
        return null;
      },
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: (_isLoading || _isGoogleLoading) ? null : _signInWithEmailAndPassword,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        shadowColor: Colors.blue.withOpacity(0.3),
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
          : const Text(
              '登入',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '或',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
    return OutlinedButton.icon(
      onPressed: (_isLoading || _isGoogleLoading) ? null : _signInWithGoogle,
      icon: _isGoogleLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Container(
              padding: const EdgeInsets.all(2),
              child: Image.asset(
                'assets/icons/google.png',
                height: 20,
                width: 20,
              ),
            ),
      label: Text(
        _isGoogleLoading ? '登入中...' : '使用 Google 登入',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _buildRegisterPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '還沒有帳號？',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: (_isLoading || _isGoogleLoading)
              ? null
              : () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => RegisterScreen(
                        onRegisterSuccess: widget.onLoginSuccess,
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          )),
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                },
          child: Text(
            '立即註冊',
            style: TextStyle(
              color: Colors.blue.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestModeButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TextButton.icon(
        onPressed: (_isLoading || _isGoogleLoading) ? null : _continueAsGuest,
        icon: Icon(
          Icons.person_outline,
          color: Colors.grey.shade600,
          size: 20,
        ),
        label: Text(
          '以訪客模式繼續',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          backgroundColor: Colors.grey.shade50,
        ),
      ),
    );
  }
}
