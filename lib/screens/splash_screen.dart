import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart'; // ✅ Add this import
import '../models/user_model.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  String _version = ''; // ✅ Store version number

  @override
  void initState() {
    super.initState();
    _loadVersion(); // ✅ Load version info
    _navigateNext();
  }

  // ✅ Load app version
  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'v${packageInfo.version}'; // e.g., "v1.0.0"
      // Or use: _version = 'v${packageInfo.version}+${packageInfo.buildNumber}'; // e.g., "v1.0.0+1"
    });
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 3));

    final isLoggedIn = await SessionManager.isLoggedIn();
    final userId = await SessionManager.getUserId();

    if (isLoggedIn && userId != null && userId.isNotEmpty) {
      // ✅ Load user from local storage
      UserModel? user = await _authService.getUserLocally();

      // Refresh from server (safe with timeout + error handling)
      final refreshedUser = await _authService
          .refreshUserFromServer(userId)
          .timeout(const Duration(seconds: 5), onTimeout: () => null)
          .catchError((e) {
            debugPrint("❌ Refresh user failed: $e");
            return null;
          });

      user = refreshedUser ?? user;

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(user: user!)),
        );
        return;
      }
    }

    print("➡️ Splash: isLoggedIn=$isLoggedIn, userId=$userId");

    // ❌ Not logged in → go to LoginScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFEBF0), Color(0xFFE5D6FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/images/dance_logo.png',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 40), // Space between logo and version
            // ✅ Version Number
            Text(
              _version,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
