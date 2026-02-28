import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../constants.dart';

class MyBatchesScreen extends StatefulWidget {
  final UserModel user;

  const MyBatchesScreen({super.key, required this.user});

  @override
  State<MyBatchesScreen> createState() => _MyBatchesScreenState();
}

class _MyBatchesScreenState extends State<MyBatchesScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> enrolledBatches = [];
  Set<String> ratedBatchIds = {};
  final String baseUrl = 'http://147.93.19.17:5002';
  @override
  void initState() {
    super.initState();
    fetchEnrolledBatches();
  }

  // ✅ YOUR API LOGIC
  Future<void> fetchEnrolledBatches() async {
    try {
      final batchRes = await http.get(
        Uri.parse('$baseUrl/api/transactions/enrolled/${widget.user.id}'),
      );

      final ratingRes = await http.get(
        Uri.parse('$baseUrl/api/ratings/user/${widget.user.id}'),
      );

      if (batchRes.statusCode == 200 && ratingRes.statusCode == 200) {
        final transactions = jsonDecode(batchRes.body);
        final ratings = jsonDecode(ratingRes.body);

        ratedBatchIds = Set<String>.from(
          ratings.map((r) => r['batchId'] ?? ''),
        );

        enrolledBatches = List<Map<String, dynamic>>.from(transactions);

        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => isLoading = false);
    }
  }

 @override
Widget build(BuildContext context) {
  return RefreshIndicator(
    onRefresh: fetchEnrolledBatches, // 🔁 Pull-to-refresh hook
    child: isLoading
        ? const Center(child: CircularProgressIndicator())
        : enrolledBatches.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No enrolled batches')),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: enrolledBatches.length,
                itemBuilder: (context, index) {
                  final batch = enrolledBatches[index];
                  final isRated =
                      ratedBatchIds.contains(batch['batchId']);

                  return Card(
                    child: ListTile(
                      title: Text(batch['batchName'] ?? 'Batch'),
                      subtitle: Text(batch['studioName'] ?? 'Studio'),
                      trailing: isRated
                          ? const Icon(Icons.check, color: Colors.green)
                          : const Text('Rate'),
                    ),
                  );
                },
              ),
  );
}
}
