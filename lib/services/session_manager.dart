import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart'; // ✅ Import UserModel

class SessionManager {
  // Keys for SharedPreferences
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyUserId = 'userId';
  static const String _keyUserData =
      'userData'; // ✅ New key for storing user data

  // ✅ Save user session with userId
  static Future<void> saveUserSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserId, userId);
  }

  // ✅ NEW: Save complete user data locally
  static Future<void> saveUserLocally(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserData, jsonEncode(user.toJson()));
    // Also save userId for quick access
    if (user.id != null) {
      await prefs.setString(_keyUserId, user.id!);
    }
  }

  // ✅ NEW: Get user data from local storage
  static Future<UserModel?> getUserLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_keyUserData);

    if (userDataString == null || userDataString.isEmpty) {
      return null;
    }

    try {
      final userJson = jsonDecode(userDataString);
      return UserModel.fromJson(userJson);
    } catch (e) {
      print('❌ Error parsing user data: $e');
      return null;
    }
  }

  // ✅ Clear all session data
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ✅ Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // ✅ Get userId
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  // ✅ NEW: Update specific user field locally
  static Future<void> updateUserField(String field, dynamic value) async {
    final user = await getUserLocally();
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userJson = user.toJson();
    userJson[field] = value;
    await prefs.setString(_keyUserData, jsonEncode(userJson));
  }

  // ✅ NEW: Update user's studioStatus specifically
  static Future<void> updateStudioStatus(String status) async {
    await updateUserField('studioStatus', status);
  }
}
