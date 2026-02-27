// ✅ login_with_otp_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/session_manager.dart';

class LoginWithOTPScreen extends StatefulWidget {
  final String email;
  final bool isNewUser;

  const LoginWithOTPScreen({
    super.key,
    required this.email,
    this.isNewUser = false, // default = existing user
  });

  @override
  State<LoginWithOTPScreen> createState() => _LoginWithOTPScreenState();
}

class _LoginWithOTPScreenState extends State<LoginWithOTPScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final String baseUrl = 'http://147.93.19.17:5001/api/user';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> resendOTP() async {
    final response = await http.post(
      Uri.parse('$baseUrl/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': widget.email}),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent successfully!')),
      );
    } else {
      final body = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend OTP: ${body['message']}')),
      );
    }
  }

  Future<void> verifyOTP() async {
    final normalizedEmail = widget.email.toLowerCase().trim();

    // 👇 Build request body conditionally
    final Map<String, dynamic> body = {
      'email': normalizedEmail,
      'otp': _otpController.text.trim(),
    };

    if (widget.isNewUser) {
      body['firstName'] = _firstNameController.text.trim();
      body['lastName'] = _lastNameController.text.trim();
    }

    final verifyResponse = await http.post(
      Uri.parse('$baseUrl/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    try {
      if (verifyResponse.statusCode == 200) {
        final userJson = jsonDecode(verifyResponse.body)['user'];

        // 🚨 Check if disabled
        if ((userJson['status'] ?? '').toString().toLowerCase() == "disabled") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "This account has been disabled by the admin. Please try another email or contact support.",
              ),
              backgroundColor: Colors.red,
            ),
          );
          return; // ⛔ stop here
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP Verified Successfully!')),
        );

        // Save locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userJson['_id']);
        await prefs.setString('userEmail', userJson['email']);
        await prefs.setString('userFirstName', userJson['firstName'] ?? '');
        await prefs.setString('userLastName', userJson['lastName'] ?? '');
        await SessionManager.saveUserSession(userJson['_id']); // ✅ auto-login session

        Navigator.pushReplacementNamed(
          context,
          '/home',
          arguments: UserModel.fromJson(userJson),
        );
      } else {
        final body = jsonDecode(verifyResponse.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid OTP: ${body['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected response format')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Let’s Get Started!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // 👇 Only show first/last name if it's a new user
              if (widget.isNewUser) ...[
                _buildTextField(_firstNameController, 'Enter your first name'),
                const SizedBox(height: 16),
                _buildTextField(_lastNameController, 'Enter your last name'),
                const SizedBox(height: 16),
              ],

              TextField(
                readOnly: true,
                controller: TextEditingController(text: widget.email),
                decoration: InputDecoration(
                  hintText: 'Enter your email id',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              _buildOTPField(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A5ED4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Verify OTP',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hintText) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildOTPField() {
    return TextField(
      controller: _otpController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: 'Enter OTP',
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: TextButton(
          onPressed: resendOTP,
          child: const Text('Resend OTP', style: TextStyle(color: Colors.blue)),
        ),
      ),
    );
  }
}
