import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/studio_model.dart';

class StudioService {
  static final StudioService _instance = StudioService._internal();
  factory StudioService() => _instance;
  StudioService._internal();

  static const String _baseUrl = 'http://147.93.19.17:5002/api/studios';


  /// ✅ Fetch all studios
  Future<List<StudioModel>> getAllStudios() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);

        // ✅ Only include studios with status 'Approved'
        final filtered = jsonData
            .where((json) => json['status'] == 'Approved')
            .map((json) => StudioModel.fromJson(json))
            .toList();

        return filtered;
      } else {
        debugPrint('❌ Failed to load studios: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching studios: $e');
      return [];
    }
  }


  /// ✅ Register a new studio
  Future<bool> registerStudio(StudioModel studio) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(studio.toJson()),
      );

      if (response.statusCode == 201) {
        debugPrint('✅ Studio created');
        return true;
      } else {
        debugPrint('❌ Failed to create studio: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error posting studio: $e');
      return false;
    }
  }

  /// ✅ Fetch a studio by ID
  Future<StudioModel?> getStudioById(String id) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$id'));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return StudioModel.fromJson(jsonData);
      } else {
        debugPrint('❌ Failed to load studio: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching studio by ID: $e');
      return null;
    }
  }

  /// ✅ Delete a studio
  Future<bool> deleteStudio(String id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/$id'));

      if (response.statusCode == 200) {
        debugPrint('✅ Studio deleted');
        return true;
      } else {
        debugPrint('❌ Failed to delete studio: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting studio: $e');
      return false;
    }
  }

  /// 🔄 Optional: Update a studio
  Future<bool> updateStudio(String id, StudioModel updatedStudio) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updatedStudio.toJson()),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Studio updated');
        return true;
      } else {
        debugPrint('❌ Failed to update studio: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error updating studio: $e');
      return false;
    }
  }
}
