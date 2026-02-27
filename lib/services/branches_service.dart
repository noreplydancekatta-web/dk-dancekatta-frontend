import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/branch_model.dart';

class BranchesService {
  static Future<BranchModel> getBranchById(String branchId) async {
    final uri = Uri.parse('http://147.93.19.17:5002/api/branches/$branchId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return BranchModel.fromJson(data);
    } else {
      throw Exception('Failed to load branch details for ID: $branchId');
    }
  }
}