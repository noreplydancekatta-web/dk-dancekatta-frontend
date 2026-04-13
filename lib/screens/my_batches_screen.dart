import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/user_model.dart';

class MyBatchesScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback? goToHomeTab;

  const MyBatchesScreen({super.key, required this.user, this.goToHomeTab});

  @override
  State<MyBatchesScreen> createState() => _MyBatchesScreenState();
}

class _MyBatchesScreenState extends State<MyBatchesScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool isLoading = true;

  List<Map<String, dynamic>> enrolledBatches = [];
  Set<String> ratedBatchIds = {};

  final String baseUrl = 'http://147.93.19.17:5002';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    fetchEnrolledBatches();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchEnrolledBatches(); // ensures refresh on tab switch
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchEnrolledBatches();
    }
  }

  // Called every time this widget is re-inserted into the tree
  // (e.g. navigating back to this tab after enrolling)
  @override
  void didUpdateWidget(covariant MyBatchesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    fetchEnrolledBatches();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  // =============================
  // FILTERS
  // =============================

  List<Map<String, dynamic>> get allBatches => enrolledBatches;

  List<Map<String, dynamic>> get activeBatches {
    final now = DateTime.now();
    return enrolledBatches.where((b) {
      final endDate = DateTime.tryParse(b['toDate'] ?? '');
      if (endDate == null) return false;
      return endDate.isAfter(now);
    }).toList();
  }

  List<Map<String, dynamic>> get endedBatches {
    final now = DateTime.now();
    return enrolledBatches.where((b) {
      final endDate = DateTime.tryParse(b['toDate'] ?? '');
      if (endDate == null) return false;
      return endDate.isBefore(now);
    }).toList();
  }

  // =============================
  // FETCH BATCHES
  // =============================

  Future<void> fetchEnrolledBatches() async {
    setState(() {
      isLoading = true;
    });

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
          ratings.map((r) {
            final batchId = r['batchId'];
            if (batchId is Map) {
              return batchId['_id'].toString();
            }
            return batchId.toString();
          }),
        );

        enrolledBatches = List<Map<String, dynamic>>.from(transactions);
      }
    } catch (e) {
      debugPrint("Fetch error $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to load batches"),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  // =============================
  // SUBMIT RATING
  // =============================

  Future<void> submitRating(
    String studioId,
    String batchId,
    double rating,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ratings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.user.id,
          'studioId': studioId,
          'batchId': batchId,
          'rating': rating,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          ratedBatchIds.add(batchId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Rating submitted"),
            backgroundColor: Colors.green,
          ),
        );

        fetchEnrolledBatches();
      }
    } catch (e) {
      debugPrint("Rating error $e");
    }
  }

  // =============================
  // FETCH STUDIO
  // =============================

  Future<Map<String, dynamic>?> fetchStudioById(String studioId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/studios/$studioId'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint("Studio fetch error $e");
    }
    return null;
  }

  // =============================
  // GENERATE INVOICE
  // =============================

  Future<void> generateInvoice(
    Map<String, dynamic> txn,
    Map<String, dynamic>? studio,
  ) async {
    final pdf = pw.Document();

    final roboto = pw.Font.ttf(
      await rootBundle.load("assets/fonts/Roboto-VariableFont_wdth,wght.ttf"),
    );

    final now = DateTime.now();

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: roboto),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "DanceKatta Invoice",
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Customer ID: ${widget.user.id}"),
              pw.Text("Studio: ${studio?['studioName'] ?? 'DanceKatta'}"),
              pw.Text("Payment Date: $now"),
              pw.SizedBox(height: 20),
              pw.Text("Amount Paid: ₹${txn['paymentAmount']}"),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // =============================
  // BATCH CARD UI
  // =============================

  Widget _buildBatchList(List<Map<String, dynamic>> batches) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (batches.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(
            child: Text(
              "No batches found",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: batches.length,
      itemBuilder: (context, index) {
        final batch = batches[index];

        final batchId = batch['batchId'] is Map
            ? batch['batchId']['_id']
            : batch['batchId'];

        // ✅ Read toDate from top-level transaction field
        final endDate = DateTime.tryParse(batch['toDate'] ?? '');
        final isEnded = endDate != null && endDate.isBefore(DateTime.now());
        final isRated = ratedBatchIds.contains(batchId?.toString() ?? '');

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: Title + Download button ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        "${batch['style']} • ${batch['level']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),
                Text(batch['studioName'] ?? ''),
                Text("₹${batch['paymentAmount']} Paid"),
                const SizedBox(height: 8),

                // ── Row 2: Status badge + Rating (for ended) ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isEnded ? Colors.grey[200] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isEnded ? "Ended" : "Active",
                        style: TextStyle(
                          color: isEnded ? Colors.black54 : Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    // Rating — only for ended batches
                    if (isEnded)
                      isRated
                          ? const Text(
                              "⭐ Rated",
                              style: TextStyle(fontSize: 13),
                            )
                          : RatingBar.builder(
                              initialRating: 0,
                              itemCount: 5,
                              itemSize: 22,
                              itemBuilder: (_, __) =>
                                  const Icon(Icons.star, color: Colors.amber),
                              onRatingUpdate: (rating) {
                                submitRating(
                                  batch['studioId'].toString(),
                                  batchId.toString(),
                                  rating,
                                );
                              },
                            ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =============================
  // BUILD
  // =============================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          widget.goToHomeTab?.call();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "Enrolled Batches",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              widget.goToHomeTab?.call();
            },
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "All (${allBatches.length})"),
              Tab(text: "Active (${activeBatches.length})"),
              Tab(text: "Ended (${endedBatches.length})"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            RefreshIndicator(
              onRefresh: fetchEnrolledBatches,
              child: _buildBatchList(allBatches),
            ),
            RefreshIndicator(
              onRefresh: fetchEnrolledBatches,
              child: _buildBatchList(activeBatches),
            ),
            RefreshIndicator(
              onRefresh: fetchEnrolledBatches,
              child: _buildBatchList(endedBatches),
            ),
          ],
        ),
      ),
    );
  }
}
