import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dance_style_model.dart';

class DanceStyleService {
  final String baseUrl = "http://147.93.19.17:5002";

  Future<List<DanceStyleModel>> fetchDanceStyles() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/dance-styles'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        // Debug: print the fetched data
        print('Dance styles fetched: $data');
        return data.map((json) {
          final style = DanceStyleModel.fromJson(json);
          return style;
        }).toList();
      } else {
        print(
          'Failed to fetch dance styles. Status code: ${response.statusCode}',
        );
        throw Exception('Failed to load dance styles');
      }
    } catch (e) {
      print('Error fetching dance styles: $e');
      throw Exception('Error fetching dance styles');
    }
  }
}
