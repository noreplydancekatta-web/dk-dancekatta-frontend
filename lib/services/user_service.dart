import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class UserService {
  static const String _baseUrl = 'http://147.93.19.17:5002/api/users';

  /// Fetch user data by ID
  static Future<UserModel?> fetchUserById(String userId) async {
    try {
      print('Fetching user with ID: $userId');
      final response = await http.get(Uri.parse('$_baseUrl/$userId'));

      print('Fetch response status: ${response.statusCode}');
      print('Fetch response body: ${response.body}');

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        return UserModel.fromJson(userData);
      } else {
        print('Failed to fetch user: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  /// Update user profile
  static Future<UserModel?> updateUserProfile(String userId, Map<String, dynamic> userData) async {
    try {
      print('Updating user with ID: $userId');
      print('Update data: ${jsonEncode(userData)}');

      final response = await http.put(
        Uri.parse('$_baseUrl/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      print('Update response status: ${response.statusCode}');
      print('Update response body: ${response.body}');

      if (response.statusCode == 200) {
        final updatedUserData = jsonDecode(response.body);
        return UserModel.fromJson(updatedUserData);
      } else {
        print('Failed to update user: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error updating user: $e');
      return null;
    }
  }
}