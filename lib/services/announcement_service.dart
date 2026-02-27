import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/announcement_model.dart';

class AnnouncementService {
  static Future<List<Announcement>> fetchAnnouncements() async {
    try {
      final response = await http.get(
        Uri.parse('http://147.93.19.17:5002/api/announcements'),
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