// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  final String baseUrl = "http://147.93.19.17:5002/api/users";

  Future<UserModel?> _handleUserLogin(UserModel user) async {
    if (user.status == "Disabled") {
      // Clear saved user if any
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Don’t allow login
      throw Exception("Your account has been disabled. Please contact support.");
    }

    // Save active user
    await saveUserLocally(user);
    return user;
  }

  /// -------------------------
  /// 1️⃣ Duplicate Email Check
  /// -------------------------
  Future<bool> isEmailRegistered(String email) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/email/$email'));

      if (response.statusCode == 200) {
        // Email exists
        return true;
      } else if (response.statusCode == 404) {
        // Email not found
        return false;
      } else {
        print("Email check error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Email check exception: $e");
      return false;
    }
  }

  /// -------------------------
  /// 2️⃣ Manual Signup
  /// -------------------------
  Future<UserModel?> signupUser(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        final userJson = jsonDecode(response.body);
        final user = UserModel.fromJson(userJson);

        // 🚨 Disabled user check
        if (user.status == "Disabled") {
          throw Exception("This account has been disabled by the admin. Please try another email or contact support.");
        }
        await saveUserLocally(user);
        return user;
      } else {
        print("Signup failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Signup exception: $e");
      return null;
    }
  }

  /// -------------------------
  /// 3️⃣ Google Login
  /// -------------------------
  Future<UserModel?> loginWithGoogle(Map<String, dynamic> googleData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check-google'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(googleData),
      );

      if (response.statusCode == 200) {
        final userJson = jsonDecode(response.body)['user'];
        final user = UserModel.fromJson(userJson);
        // 🚨 Disabled user check
        if (user.status == "Disabled") {
          throw Exception("This account has been disabled, Please try another email or contact us.");
        }
        await saveUserLocally(user);
        return user;
      } else {
        print("Google login failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Google login exception: $e");
      return null;
    }
  }

  /// -------------------------
  /// 4️⃣ OTP Login (assuming your backend handles OTP)
  /// -------------------------
  Future<UserModel?> loginWithOTP(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login-otp'), // Replace with your OTP login endpoint
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "otp": otp}),
      );

      if (response.statusCode == 200) {
        final userJson = jsonDecode(response.body);
        final user = UserModel.fromJson(userJson);
        // 🚨 Disabled user check
        if (user.status == "Disabled") {
          throw Exception("This account has been disabled by the admin. Please try another email or contact support.");
        }
        await saveUserLocally(user);
        return user;
      } else {
        print("OTP login failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("OTP login exception: $e");
      return null;
    }
  }

  /// -------------------------
  /// 5️⃣ Save User Locally
  /// -------------------------
  Future<void> saveUserLocally(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', user.id ?? '');
    await prefs.setString('userDetail', jsonEncode(user.toJson()));
  }

  /// -------------------------
  /// 🔄 Refresh User From Server
  /// -------------------------
  Future<UserModel?> refreshUserFromServer(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$userId'));
      if (response.statusCode == 200) {
        final userJson = jsonDecode(response.body);
        final refreshedUser = UserModel.fromJson(userJson);

        // Save fresh user locally
        await saveUserLocally(refreshedUser);

        return refreshedUser;
      } else {
        print("Refresh user failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Refresh user exception: $e");
      return null;
    }
  }

  /// -------------------------
  /// 6️⃣ Get User Locally
  /// -------------------------
  Future<UserModel?> getUserLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('userDetail');
    if (userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  /// -------------------------
  /// 🔄 Update User Profile (Finish/Edit Profile)
  /// -------------------------
  Future<UserModel?> updateUserProfile(String userId, Map<String, dynamic> updatedData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$userId'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(updatedData),
      );

      if (response.statusCode == 200) {
        final userJson = jsonDecode(response.body);
        final updatedUser = UserModel.fromJson(userJson['user'] ?? userJson);

        // 🔑 Save updated user locally
        await saveUserLocally(updatedUser);

        return updatedUser;
      } else {
        print("Update profile failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Update profile exception: $e");
      return null;
    }
  }





  /// -------------------------
  /// 7️⃣ Logout
  /// -------------------------
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('userDetail');
  }
}
