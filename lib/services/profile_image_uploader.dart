// lib/services/profile_image_uploader.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfileImageUploader {
  final String baseUrl; // e.g. "https://your-domain.com"
  final String? authToken; // optional, if you use JWT/Bearer token

  ProfileImageUploader({
    required this.baseUrl,
    this.authToken,
  });

  Future<String> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    final uri = Uri.parse('$baseUrl/api/users/$userId/profile-photo');
    final request = http.MultipartRequest('POST', uri);

    // Add auth token if needed
    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    // Add the file
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['profileImageUrl'] != null) {
        return data['profileImageUrl'];
      } else {
        throw Exception('Server did not return profileImageUrl');
      }
    } else {
      throw Exception('Upload failed: ${response.statusCode} ${response.body}');
    }
  }
}
