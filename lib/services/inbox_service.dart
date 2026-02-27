import 'dart:convert';
import 'package:http/http.dart' as http;

class InboxService {
  static const String baseUrl = 'http://147.93.19.17:5002/api/inbox';

  // Fetch list of seen announcement IDs for the given user
  static Future<List<String>> fetchSeenAnnouncementIds(String userId) async {
    try {
      print("📥 Fetching seen announcements for userId: $userId");
      final response = await http.get(Uri.parse('$baseUrl/$userId'));

      print("🔍 GET Response Code: ${response.statusCode}");
      print("🔍 GET Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['seenAnnouncements'] ?? []);
      } else {
        throw Exception('Failed to fetch seen announcements');
      }
    } catch (e) {
      print("❌ Error fetching seen announcements: $e");
      rethrow;
    }
  }

  // Mark an announcement as seen for a user
  static Future<void> markAsSeen(String userId, String announcementId) async {
    try {
      print("📤 Marking as seen → userId: $userId | announcementId: $announcementId");

      final response = await http.post(
        Uri.parse('$baseUrl/seen'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'announcementId': announcementId,
        }),
      );

      print("📬 POST Response Code: ${response.statusCode}");
      print("📬 POST Response Body: ${response.body}");

      if (response.statusCode != 200) {
        throw Exception('Failed to mark announcement as seen');
      }
    } catch (e) {
      print("❌ Error marking announcement as seen: $e");
      rethrow;
    }
  }
}