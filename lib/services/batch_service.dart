import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/batch_model.dart';
import '../models/branch_model.dart';
import 'branches_service.dart';

class BatchService {
  static Future<List<BatchModel>> getBatchesByStudioAndBranch(String studioId, String branchId) async {
    try {
      print('🔄 BatchService: Fetching batches for studio: $studioId, branch: $branchId');

      final uri = Uri.parse(
        'http://147.93.19.17:5002/api/batches/filter?studioId=$studioId&branch=$branchId',
      );

      print('🔗 BatchService: Making request to: $uri');
      final response = await http.get(uri);

      print('📊 BatchService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        print('✅ BatchService: Successfully fetched ${data.length} batches');

        final List<BatchModel> populatedBatches = [];

        for (final batchJson in data) {
          final dynamic branchData = batchJson['branch'];

          BranchModel? fullBranch;

          if (branchData is String) {
            // Case 1: branch is a string ID. Make a secondary API call.
            try {
              fullBranch = await BranchesService.getBranchById(branchData);
            } catch (e) {
              print('❌ BatchService: Failed to fetch branch details for ID: $branchData, Error: $e');
            }
          } else if (branchData is Map) {
            // Case 2: branch is already an embedded object. No extra API call needed.
            try {
              fullBranch = BranchModel.fromJson(branchData.cast<String, dynamic>());
            } catch (e) {
              print('❌ BatchService: Failed to parse embedded branch data. Error: $e');
            }
          } else {
            // Handle other cases or keep fullBranch as null
            fullBranch = null;
          }

          final BatchModel batchWithFullBranch = BatchModel.fromJson(batchJson, branchObject: fullBranch);
          populatedBatches.add(batchWithFullBranch);
        }

        print('✅ BatchService: Successfully processed ${populatedBatches.length} batch models with populated branch data');

        return populatedBatches;
      } else {
        print('❌ BatchService: Failed to load batches - Status: ${response.statusCode}');
        print('📄 BatchService: Response body: ${response.body}');
        throw Exception('Failed to load batches: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ BatchService: Error fetching batches: $e');
      return [];
    }
  }
}