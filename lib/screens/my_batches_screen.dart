import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../models/user_model.dart';
import '../models/batch_model.dart';
import '../models/branch_model.dart';
import '../constants.dart';
import 'batch_detail_screen.dart';

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
  Map<String, dynamic>? platformFeeData;
  final String baseUrl = 'http://147.93.19.17:5002';

  @override
  void initState() {
    super.initState();
    fetchEnrolledBatches();
    fetchPlatformFee();
  }

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
          ratings.map((r) => r['batchId'] as String? ?? ''),
        );
        enrolledBatches = List<Map<String, dynamic>>.from(transactions);
      }
    } catch (e) {
      debugPrint('Error fetching enrolled batches: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchPlatformFee() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/platformfees'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          setState(() => platformFeeData = data.first);
        }
      }
    } catch (e) {
      debugPrint('Error fetching platform fee: $e');
    }
  }

  Future<void> refreshRatings() async {
    try {
      final ratingRes = await http.get(
        Uri.parse('$baseUrl/api/ratings/user/${widget.user.id}'),
      );
      if (ratingRes.statusCode == 200) {
        final ratings = jsonDecode(ratingRes.body);
        setState(() {
          ratedBatchIds = Set<String>.from(
            ratings.map((r) => r['batchId'] as String? ?? ''),
          );
        });
      }
    } catch (e) {
      debugPrint('Error refreshing ratings: $e');
    }
  }

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

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() => ratedBatchIds.add(batchId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await fetchEnrolledBatches();
        await refreshRatings();
      } else {
        String errorMsg = 'Failed to submit rating';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            errorMsg = decoded['message'];
          }
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error submitting rating')));
    }
  }

  double _parseDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<Map<String, dynamic>?> fetchStudioById(String studioId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/studios/$studioId'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching studio: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> fetchOwner(String ownerId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/users/$ownerId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to fetch owner');
  }

  Future<void> generateInvoice(
    Map<String, dynamic> txn,
    Map<String, dynamic>? studio,
  ) async {
    final roboto = pw.Font.ttf(
      await rootBundle.load("assets/fonts/Roboto-VariableFont_wdth,wght.ttf"),
    );
    final robotoItalic = pw.Font.ttf(
      await rootBundle.load(
        "assets/fonts/Roboto-Italic-VariableFont_wdth,wght.ttf",
      ),
    );

    final pdf = pw.Document();
    final DateTime now = DateTime.now();
    final DateTime paymentDate = txn['paymentDate'] != null
        ? DateTime.tryParse(txn['paymentDate']) ?? now
        : now;

    final double tutorFee = _parseDouble(txn['fee']);
    final double discountAmount = _parseDouble(txn['discountAmount']);
    final double discountedTutorFee = tutorFee - discountAmount;
    final double platformPercent = _parseDouble(
      platformFeeData?['feePercent'],
      0,
    );
    final double gstPercent = _parseDouble(platformFeeData?['gstPercent'], 0);
    final double platformFee = (discountedTutorFee * platformPercent) / 100;
    final double gstOnPlatformFee = (platformFee * gstPercent) / 100;
    final double totalFee = discountedTutorFee + platformFee + gstOnPlatformFee;
    final double totalAmountPaid = _parseDouble(txn['paymentAmount'], totalFee);
    final String? couponCode = txn['couponCode'] as String?;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: roboto,
          italic: robotoItalic,
          fontFallback: [roboto],
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DanceKatta',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Studio name: ${studio?['studioName'] ?? 'DanceKatta Studio'}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'Address: ${studio?['registeredAddress'] ?? 'Not Provided'}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      if (studio?['gstNumber'] != null &&
                          studio!['gstNumber'].toString().isNotEmpty)
                        pw.Text(
                          'GSTIN: ${studio!['gstNumber']}',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Invoice Date: ${paymentDate.day}-${paymentDate.month}-${paymentDate.year}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'Customer ID: ${widget.user.id}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'PAID',
                        style: pw.TextStyle(
                          color: PdfColors.green,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BILLED TO',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${widget.user.firstName} ${widget.user.lastName}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        widget.user.country ?? 'N/A',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        widget.user.email,
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        widget.user.mobile ?? 'N/A',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.Container(
                color: PdfColors.grey300,
                padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text(
                        'DESCRIPTION',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'PRICE',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'DISCOUNT',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'AMOUNT (INR)',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8.0),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('${txn['style']} - ${txn['level']}'),
                          pw.Text(
                            'Transaction ID: ${txn['razorpayPaymentId'] ?? 'N/A'}',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text('₹${tutorFee.toStringAsFixed(2)}'),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        discountAmount > 0
                            ? '-₹${discountAmount.toStringAsFixed(2)}'
                            : '₹0.00',
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        '₹${(tutorFee - discountAmount).toStringAsFixed(2)}',
                      ),
                    ),
                  ],
                ),
              ),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 240,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (discountAmount > 0) ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Discount (${((discountAmount / tutorFee) * 100).round()}%)',
                            ),
                            pw.Text('-₹${discountAmount.toStringAsFixed(2)}'),
                          ],
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Fee after Discount'),
                            pw.Text(
                              '₹${(tutorFee - discountAmount).toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      ] else ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [pw.Text('Discount'), pw.Text('₹0.00')],
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Fee after Discount'),
                            pw.Text('₹${tutorFee.toStringAsFixed(2)}'),
                          ],
                        ),
                      ],
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Platform Fee ${platformPercent.toStringAsFixed(0)}%',
                          ),
                          pw.Text('₹${platformFee.toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('GST ${gstPercent.toStringAsFixed(0)}%'),
                          pw.Text('₹${gstOnPlatformFee.toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Amount Paid (INR)',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            '₹${totalAmountPaid.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'PAYMENTS',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '₹${totalAmountPaid.toStringAsFixed(2)} was paid on ${paymentDate.day}-${paymentDate.month}-${paymentDate.year} via ${txn['paymentMethod'] ?? 'Online'}',
                style: pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'DISCOUNT',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              if (discountAmount > 0)
                pw.Text(
                  '${couponCode ?? "Coupon"} - ₹${discountAmount.toStringAsFixed(2)} '
                  '(${tutorFee > 0 ? ((discountAmount / tutorFee) * 100).round() : 0}%)',
                  style: pw.TextStyle(fontSize: 10),
                )
              else
                pw.Text(
                  'No Discount Applied',
                  style: pw.TextStyle(fontSize: 10),
                ),
              pw.SizedBox(height: 12),
              pw.Text(
                'NOTES',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Center(
                child: pw.Text(
                  'Thank you for trusting DanceKatta!\nFor support, contact support@dancekatta.com',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: fetchEnrolledBatches,
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
                final isRated = ratedBatchIds.contains(
                  batch['batchId'] as String? ?? '',
                );
                final isEnded =
                    DateTime.tryParse(
                      batch['toDate'] ?? '',
                    )?.isBefore(DateTime.now()) ??
                    false;
                final statusText = isEnded ? 'Ended' : 'Active';

                return GestureDetector(
                  onTap: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      final batchId = batch['batchId'] is Map
                          ? batch['batchId']['_id']
                          : batch['batchId'];

                      final response = await http.get(
                        Uri.parse('$baseUrl/api/batches'),
                      );

                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } // close loading

                      if (response.statusCode == 200) {
                        final List data = jsonDecode(response.body);

                        final batchData = data
                            .cast<Map<String, dynamic>>()
                            .firstWhere(
                              (b) => b['_id'] == batchId,
                              orElse: () => {},
                            );

                        if (batchData.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Batch not found'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final batchModel = BatchModel.fromJson(batchData);

                        final branchModel = BranchModel(
                          id: batchModel.branch,
                          name: batch['branchName'] ?? 'Unknown Branch',
                          address:
                              batch['branchAddress'] ?? 'Address not available',
                          area: '',
                          contactNo: batch['branchContactNo'] ?? '',
                          mapLink: '',
                        );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BatchDetailScreen(
                              batch: batchModel,
                              branch: branchModel,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to load batch details'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },

                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Title + Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${batch['style']} • ${batch['level']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: isEnded
                                    ? Colors.black
                                    : Colors.blueAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // ✅ Studio name
                        Text(batch['studioName'] ?? 'Studio'),

                        // ✅ Payment
                        Text(
                          "Payment Successful ₹${batch['paymentAmount'] ?? '0'}/-",
                        ),
                        const SizedBox(height: 6),

                        // ✅ Rating + Invoice
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Rating stars or rated check
                            if (isEnded)
                              isRated
                                  ? const Text("⭐ You rated this batch")
                                  : RatingBar.builder(
                                      initialRating: 0,
                                      minRating: 1,
                                      direction: Axis.horizontal,
                                      itemSize: 26,
                                      itemCount: 5,
                                      allowHalfRating: false,
                                      itemBuilder: (context, _) => const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                      ),
                                      onRatingUpdate: (rating) {
                                        submitRating(
                                          batch['studioId'].toString(),
                                          batch['batchId'].toString(),
                                          rating,
                                        );
                                      },
                                    )
                            else
                              const SizedBox(),

                            // ✅ Invoice download
                            IconButton(
                              icon: const Icon(Icons.download, size: 22),
                              onPressed: () async {
                                final studioData = await fetchStudioById(
                                  batch['studioId'],
                                );
                                await generateInvoice(batch, studioData);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
