import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _navigateNext();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      _version = "v ${packageInfo.version}"; // ✅ Changed format to "v 1.0.2"
    });
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 3));

    final isLoggedIn = await SessionManager.isLoggedIn();
    final userId = await SessionManager.getUserId();

    if (isLoggedIn && userId != null && userId.isNotEmpty) {
      UserModel? user = await _authService.getUserLocally();

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

        child: Stack(
          children: [
            // Logo in center
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/dance_logo.png',
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 12), // 👈 spacing

                  Text(
                    _version,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
