//final updated
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/announcement_model.dart';

class AnnouncementService {
  static Future<List<Announcement>> fetchAnnouncements(String userId) async {
    try {
      final response = await http.get(
        // ✅ Correct backend URL
        Uri.parse('http://147.93.19.17:5002/api/announcements/student/$userId'),
      );

      print('📢 Announcements GET Code: ${response.statusCode}');
      print('📢 Announcements Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.map((json) => Announcement.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch announcements');
      }
    } catch (e) {
      print("❌ Error fetching announcements: $e");
      rethrow;
    }
  }
}
