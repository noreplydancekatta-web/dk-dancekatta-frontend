// ✅ login_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_with_otp_screen.dart';
import 'signup_screen.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'finish_profile_screen.dart';
import '/models/user_model.dart';
import '/screens/home_screen.dart';
import '../services/session_manager.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final AuthService _authService = AuthService();

  Future<void> sendOTPAndNavigate() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://147.93.19.17:5001/api/user/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final isRegistered = await _authService.isEmailRegistered(email);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LoginWithOTPScreen(email: email, isNewUser: !isRegistered),
          ),
        );
      } else {
        final body = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? 'OTP sending failed.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Something went wrong.')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => isLoading = true);

    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception("Firebase user is null");
      }

      final response = await http.post(
        Uri.parse("http://147.93.19.17:5002/api/users/check-google"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": firebaseUser.email,
          "name": firebaseUser.displayName,
          "photoURL": firebaseUser.photoURL, // 🔥 FIX
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Backend error");
      }

      print("STATUS CODE: ${response.statusCode}");
      print("BODY: ${response.body}");

      final data = jsonDecode(response.body);

      if (data == null) {
        throw Exception("Empty response from backend");
      }

      // ✅ Safe handling
      final userData = data["user"] != null ? data["user"] : data;

      if (userData == null) {
        throw Exception("User data missing in response");
      }

      // ✅ Fix corrupted or missing profilePhoto
      final currentPhoto = userData["profilePhoto"]?.toString();
      final isMissing = currentPhoto == null || currentPhoto.isEmpty;
      final isCorrupt = !isMissing && !currentPhoto.startsWith('http') && !currentPhoto.startsWith('/uploads/');

      if (isMissing || isCorrupt) {
        userData["profilePhoto"] = firebaseUser.photoURL;
        
        // Update backend to persist the Google photo so it doesn't vanish on refresh
        if (firebaseUser.photoURL != null && firebaseUser.photoURL!.isNotEmpty) {
          try {
            final userId = userData["_id"] ?? userData["id"];
            if (userId != null) {
              await http.put(
                Uri.parse("http://147.93.19.17:5002/api/users/$userId"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({"profilePhoto": firebaseUser.photoURL}),
              );
            }
          } catch (e) {
            print("Failed to persist Google photo: $e");
          }
        }
      }

      final userModel = UserModel.fromJson(userData);

      await SessionManager.saveUserSession(userModel.id ?? '');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: userModel)),
      );
    } catch (e) {
      print("Google Sign-In Error: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Google Sign-In failed")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Image.asset(
                    'assets/images/dance_logo.png',
                    height: 120,
                  ),
                ),
                const SizedBox(height: 50),
                const Text(
                  'Sign In',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'Enter your email id',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : sendOTPAndNavigate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3E64FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Log in with OTP'),
                  ),
                ),
                const SizedBox(height: 40),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or', style: TextStyle(color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : _handleGoogleSignIn,
                    icon: Image.asset('assets/icons/google.png', height: 20),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3E64FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Sign Up with Email'),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
