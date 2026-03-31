// ✅ login_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_with_otp_screen.dart';
import 'signup_screen.dart';

// New imports for Google Sign-In and Firebase Auth
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Assuming you have a dummy screen for finishing the profile
// You will need to create this file
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

  // Initialize Firebase and Google Sign-In instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final AuthService _authService = AuthService();

  /// Handles the traditional OTP login process
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
        // ✅ Check if email already exists in DB
        final isRegistered = await _authService.isEmailRegistered(email);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginWithOTPScreen(
              email: email,
              isNewUser: !isRegistered, // pass flag
            ),
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
      // // 🔹 Reset GoogleSignIn and FirebaseAuth state
      // await _googleSignIn.disconnect().catchError((_) {});
      // await _googleSignIn.signOut().catchError((_) {});
      // await _auth.signOut().catchError((_) {});

      // 🔹 Begin the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return; // User canceled the sign-in process
      }

      // 🔹 Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception("Missing Google ID token or access token");
      }

      // 🔹 Sign in to Firebase with the Google credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception("Firebase user is null");
      }

      // 🔹 Call backend (check or create user automatically)
      try {
        final response = await http.post(
          Uri.parse("http://147.93.19.17:5002/api/users/check-google"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": firebaseUser.email,
            "name": firebaseUser.displayName,
          }),
        );

        // if (response.statusCode == 200) {
        //   final data = jsonDecode(response.body);

        //   // ✅ Always take user object, ignore "exists"
        //   final userModel = UserModel.fromJson(data["user"]);

        //   // 🚨 Check if disabled
        //   if (userModel.status == "Disabled") {
        //     ScaffoldMessenger.of(context).showSnackBar(
        //       const SnackBar(
        //         content: Text(
        //           "This account has been disabled by the admin. Please try another email or contact support.",
        //         ),
        //         backgroundColor: Colors.red,
        //       ),
        //     );
        //     return; // stop login
        //   }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print("Backend Response: $data");
          // ✅ Handle both cases (with "user" key or direct object)
          final userData = data["user"] ?? data;
          if (userData == null) {
            throw Exception("User data missing in backend response");
          }

          final userModel = UserModel.fromJson(userData);

          // 🚨 Check if disabled
          if (userModel.status == "Disabled") {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "This account has been disabled by the admin. Please try another email or contact support.",
                ),
                backgroundColor: Colors.red,
              ),
            );
            return; // stop login
          }

          await SessionManager.saveUserSession(userModel.id ?? '');

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeScreen(user: userModel)),
          );
        } else {
          throw Exception("Google Sign-In failed: ${response.body}");
        }
      } catch (e) {
        print("Error during Google Sign-In backend check: $e");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google Sign-In failed: $e')));
      }
    } catch (e, s) {
      print("Google Sign-In error: $e\n$s");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google Sign-In failed: $e')));
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
