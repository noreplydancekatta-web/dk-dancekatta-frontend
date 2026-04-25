// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'edit_personal_profile.dart';
import 'finish_profile_screen.dart';
import '../screens/studio_registration_screen.dart';
import 'login_screen.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/login_screen.dart';
import 'package:flutter/services.dart';
import '../services/session_manager.dart';
import '../screens/batch_detail_screen.dart';
import '../models/batch_model.dart';
import '../models/branch_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String baseUrl = 'http://147.93.19.17:5002';

  List<dynamic> enrolledBatches = [];
  Set<String> ratedBatchIds = {};
  bool isLoading = true;
  bool isExpanded = false;
  bool isUserLoading = true;
  Map<String, dynamic>? studio;
  Map<String, dynamic>? platformFeeData;

  late UserModel currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
    _refreshUserData();
    fetchEnrolledBatches();
    fetchPlatformFee();
  }

  Future<void> fetchEnrolledBatches() async {
    try {
      final batchRes = await http.get(
        Uri.parse('$baseUrl/api/transactions/enrolled/${currentUser.id}'),
      );
      final ratingRes = await http.get(
        Uri.parse('$baseUrl/api/ratings/user/${currentUser.id}'),
      );

      if (batchRes.statusCode == 200 && ratingRes.statusCode == 200) {
        final transactions = jsonDecode(batchRes.body);
        final ratings = jsonDecode(ratingRes.body);

        ratedBatchIds = Set<String>.from(
          ratings.map((r) => r['batchId'] as String? ?? ''),
        );
        enrolledBatches = List<Map<String, dynamic>>.from(transactions);

        setState(() {
          isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch data');
      }
    } catch (e) {
      debugPrint('Error fetching enrolled batches: $e');
    }
  }

  Future<void> fetchStudio(String studioId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/studios/$studioId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          studio = jsonDecode(response.body);
        });
      } else {
        debugPrint("Failed to load studio: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching studio: $e");
    }
  }

  Future<void> refreshRatingsData() async {
    try {
      final ratingRes = await http.get(
        Uri.parse('$baseUrl/api/ratings/user/${currentUser.id}'),
      );
      if (ratingRes.statusCode == 200) {
        final ratings = jsonDecode(ratingRes.body);
        setState(() {
          ratedBatchIds = Set<String>.from(ratings.map((r) => r['batchId']));
        });
      }
    } catch (e) {
      debugPrint('Error refreshing ratings data: $e');
    }
  }

  Future<void> _refreshUserData() async {
    if (currentUser.id != null) {
      final updatedUser = await UserService.fetchUserById(currentUser.id!);
      if (updatedUser != null) {
        setState(() {
          currentUser = updatedUser;
          isUserLoading = false;
        });
      } else {
        setState(() {
          isUserLoading = false;
        });
      }
    } else {
      setState(() {
        isUserLoading = false;
      });
    }
  }

  Future<void> _navigateToFinishProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FinishProfileScreen(user: currentUser)),
    );

    if (result is UserModel) {
      setState(() {
        currentUser = result;
      });
    }

    await _refreshUserData();
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: currentUser)),
    );

    if (result is UserModel) {
      setState(() {
        currentUser = result;
      });
    } else {
      await _refreshUserData();
    }
  }

  Future<void> _navigateToStudioRegistration() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudioRegistrationScreen(user: currentUser),
      ),
    );

    await _refreshUserData();
  }

  Future<bool> _showLogoutConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _logout() async {
    try {
      final shouldLogout = await _showLogoutConfirmation(context);

      if (shouldLogout) {
        await FirebaseAuth.instance.signOut();

        final GoogleSignIn googleSignIn = GoogleSignIn();

        try {
          if (await googleSignIn.isSignedIn()) {
            await googleSignIn.signOut();
          }
        } catch (e) {
          print("Google signOut error: $e");
        }

        await SessionManager.clearSession();

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('Error during logout: $e');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    }
  }

  Future<void> submitRating(
    String studioId,
    String batchId,
    double rating,
  ) async {
    try {
      final client = http.Client();
      final response = await client.post(
        Uri.parse('$baseUrl/api/ratings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': currentUser.id,
          'studioId': studioId,
          'batchId': batchId,
          'rating': rating,
        }),
      );
      client.close();

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          ratedBatchIds.add(batchId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted successfully!')),
        );
        await fetchEnrolledBatches();
        await refreshRatingsData();
      } else {
        String errorMsg = 'Failed to submit rating';
        if (response.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map && decoded['message'] != null) {
              errorMsg = decoded['message'];
            }
          } catch (_) {}
        }
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

  Future<Map<String, dynamic>?> fetchOwner(String ownerId) async {
    try {
      final response = await http.get(
        Uri.parse('http://147.93.19.17:5002/api/users/$ownerId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Owner not found: ${response.statusCode}");
        return null; // ✅ DO NOT THROW
      }
    } catch (e) {
      print("Error fetching owner: $e");
      return null; // ✅ DO NOT THROW
    }
  }

  Future<Map<String, dynamic>?> fetchStudioById(String studioId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/studios/$studioId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Failed to load studio: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching studio: $e");
      return null;
    }
  }

  Future<void> fetchPlatformFee() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/platformfees'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          setState(() {
            platformFeeData = data.first;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching platform fee: $e");
    }
  }

  Future<void> generateInvoice(
    Map<String, dynamic> txn,
    dynamic currentUser,
    Map<String, dynamic>? studio,
    Map<String, dynamic>? owner,
  ) async {
    try {
      if (owner == null && studio != null && studio['ownerId'] != null) {
        owner = await fetchOwner(studio['ownerId']);
      }
    } catch (e) {
      print("⚠️ Owner fetch failed: $e");
      owner = null; // continue without owner
    }

    // ─────────────────────────────────────────────────────────────
    // Field resolver for new vs old transactions
    // OLD transactions: style, level, fee, fromDate, toDate stored flat.
    // NEW transactions: batchId is a populated nested object.
    // txnField() checks flat first, then falls back to nested batchId.
    // ─────────────────────────────────────────────────────────────
    final dynamic rawBatchId = txn['batchId'];
    final Map<String, dynamic> batchFields = rawBatchId is Map
        ? Map<String, dynamic>.from(rawBatchId)
        : {};

    String txnField(String key) {
      final flat = txn[key];
      if (flat != null && flat.toString().isNotEmpty) return flat.toString();
      return batchFields[key]?.toString() ?? '';
    }
    // ─────────────────────────────────────────────────────────────

    final pdf = pw.Document();
    final DateTime now = DateTime.now();

    final DateTime fromDate = DateTime.tryParse(txnField('fromDate')) ?? now;
    final DateTime toDate = DateTime.tryParse(txnField('toDate')) ?? now;
    final double tutorFee = _parseDouble(
      txnField('fee').isNotEmpty ? txnField('fee') : null,
    );

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

    final DateTime paymentDate = txn['paymentDate'] != null
        ? DateTime.tryParse(txn['paymentDate']) ?? now
        : now;

    // ─────────────────────────────────────────────────────────────
    // NOTE: We use "Rs." instead of "₹" because the default PDF
    // fonts (Helvetica/Times) do not include the rupee glyph and
    // will throw an encoding error at render time.
    // To use "₹", load a TTF font (e.g. Roboto) that supports it
    // and pass it via pw.ThemeData.withFont(base: yourFont).
    // ─────────────────────────────────────────────────────────────

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
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
                      if (studio != null &&
                          studio['gstNumber'] != null &&
                          studio['gstNumber'].toString().isNotEmpty)
                        pw.Text(
                          'GSTIN: ${studio?['gstNumber'] ?? ''}',
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
                        'Customer ID: ${currentUser.id}',
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
                        '${currentUser.firstName} ${currentUser.lastName}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        currentUser.country ?? 'N/A',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        currentUser.email,
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        currentUser.mobile ?? 'N/A',
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
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DESCRIPTION',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 4),
                        ],
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
                          pw.Text(
                            '${txnField('style')} - ${txnField('level')}',
                          ),
                          pw.Text(
                            'Transaction ID: ${txn['razorpayPaymentId'] ?? 'N/A'}',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      // FIX: "Rs." instead of "₹" — default PDF fonts lack the rupee glyph
                      child: pw.Text('Rs.${tutorFee.toStringAsFixed(2)}'),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        discountAmount > 0
                            ? '-Rs.${discountAmount.toStringAsFixed(2)}'
                            : 'Rs.0.00',
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'Rs.${(tutorFee - discountAmount).toStringAsFixed(2)}',
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
                              'Discount (- Rs.${discountAmount.toStringAsFixed(2)} '
                              '(${tutorFee > 0 ? ((discountAmount / tutorFee) * 100).round() : 0}%)',
                            ),
                            pw.Text('-Rs.${discountAmount.toStringAsFixed(2)}'),
                          ],
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Fee after Discount'),
                            pw.Text(
                              'Rs.${(tutorFee - discountAmount).toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      ] else ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [pw.Text('Discount'), pw.Text('Rs.0.00')],
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Fee after Discount'),
                            pw.Text('Rs.${tutorFee.toStringAsFixed(2)}'),
                          ],
                        ),
                      ],
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Platform Fee ${platformPercent.toStringAsFixed(0)}%',
                          ),
                          pw.Text('Rs.${platformFee.toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'GST on Platform Fee ${gstPercent.toStringAsFixed(0)}%',
                          ),
                          pw.Text('Rs.${gstOnPlatformFee.toStringAsFixed(2)}'),
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
                            'Rs.${totalAmountPaid.toStringAsFixed(2)}',
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
                'Rs.${totalAmountPaid.toStringAsFixed(2)} was paid on '
                '${paymentDate.day}-${paymentDate.month}-${paymentDate.year} '
                'via ${txn['paymentMethod'] ?? 'Online'}',
                style: pw.TextStyle(fontSize: 10),
              ),

              pw.SizedBox(height: 12),
              pw.Text(
                'DISCOUNT',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              if (discountAmount > 0)
                pw.Text(
                  '${couponCode ?? "Coupon"} - Rs.${discountAmount.toStringAsFixed(2)} '
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

  Widget buildEnrolledBatches() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (enrolledBatches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("No enrolled batches found."),
      );
    }

    return Column(
      children: enrolledBatches.map((batch) {
        final isRated = ratedBatchIds.contains(
          batch['batchId'] as String? ?? '',
        );
        final rawBatchId = batch['batchId'];
        final batchFields = rawBatchId is Map
            ? Map<String, dynamic>.from(rawBatchId)
            : {};

        String getField(String key) {
          final flat = batch[key];
          if (flat != null && flat.toString().isNotEmpty)
            return flat.toString();
          return batchFields[key]?.toString() ?? '';
        }

        final isEnded =
            DateTime.tryParse(getField('toDate'))?.isBefore(DateTime.now()) ??
            false;
        final statusText = isEnded ? 'Ended' : 'Active';

        return GestureDetector(
          onTap: () async {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(child: CircularProgressIndicator()),
            );

            try {
              final batchId = batch['batchId'] is Map
                  ? batch['batchId']['_id']
                  : batch['batchId'];

              final response = await http.get(
                Uri.parse('$baseUrl/api/batches'),
              );

              Navigator.pop(context);

              if (response.statusCode == 200) {
                final List data = jsonDecode(response.body);

                final batchData = data.cast<Map<String, dynamic>>().firstWhere(
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
                  address: batch['branchAddress'] ?? 'Address not available',
                  area: '',
                  contactNo: batch['branchContactNo'] ?? '',
                  mapLink: '',
                );

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BatchDetailScreen(
                      batch: batchModel,
                      branch: branchModel,
                    ),
                  ),
                );

                if (result == true) {
                  fetchEnrolledBatches();
                }
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
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${getField('style')} • ${getField('level')}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: isEnded ? Colors.black : Colors.blueAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),
                Text(batch['studioName'] ?? 'Studio'),
                Text(
                  "Payment Successful Rs.${batch['paymentAmount'] ?? '0'}/-",
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    isEnded
                        ? isRated
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
                                    final rawBatchId = batch['batchId'];
                                    final batchId = rawBatchId is Map
                                        ? rawBatchId['_id']?.toString()
                                        : rawBatchId?.toString();

                                    final rawStudioId = batch['studioId'];
                                    final studioId = rawStudioId is Map
                                        ? rawStudioId['_id']?.toString()
                                        : rawStudioId?.toString();

                                    submitRating(
                                      studioId ?? '',
                                      batchId ?? '',
                                      rating,
                                    );
                                  },
                                )
                        : const SizedBox(),

                    IconButton(
                      icon: const Icon(Icons.download, size: 22),
                      onPressed: () async {
                        try {
                          final rawStudioId = batch['studioId'];

                          // Extract studioId safely
                          final studioId = rawStudioId is Map
                              ? rawStudioId['_id']?.toString()
                              : rawStudioId?.toString();

                          print("DEBUG batch: $batch");
                          print("DEBUG studioId: $studioId");

                          // Handle both new & old data formats
                          Map<String, dynamic>? studioData;

                          if (rawStudioId is Map) {
                            // NEW format: studioId is already a populated object
                            studioData = Map<String, dynamic>.from(rawStudioId);
                          } else if (studioId != null) {
                            // OLD format: fetch studio data from API
                            studioData = await fetchStudioById(studioId);
                          }

                          // Validate transaction data
                          if (batch['paymentAmount'] == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Invalid transaction data"),
                              ),
                            );
                            return;
                          }

                          // Generate invoice (studioData may be null — handled gracefully)
                          await generateInvoice(
                            batch,
                            currentUser,
                            studioData,
                            null,
                          );
                        } catch (e, stack) {
                          // Improved error logging to help diagnose future issues
                          print("Invoice error: $e");
                          print("Invoice stack trace: $stack");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Invoice generation failed: $e"),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStudioTile() {
    if (isUserLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          height: 48,
          child: Center(child: LinearProgressIndicator()),
        ),
      );
    }

    if (!currentUser.isProfessionalChoreographer) {
      return const SizedBox.shrink();
    }

    final double experienceYears =
        double.tryParse(currentUser.experience ?? "0") ?? 0;
    if (experienceYears < 1) {
      return const SizedBox.shrink();
    }

    final rawStatus = currentUser.studioStatus?.trim().toLowerCase() ?? '';

    if (rawStatus.isEmpty) {
      return _buildListTile(
        "Create Studio Profile",
        Icons.add_business,
        _navigateToStudioRegistration,
      );
    }

    switch (rawStatus) {
      case 'pending':
        return _buildStatusContainer(
          title: "Studio Under Review",
          subtitle: "Your studio is under verification",
          icon: Icons.hourglass_top,
          bgColor: Colors.orange,
        );
      case 'approved':
        return _buildStatusContainer(
          title: "Studio Approved",
          subtitle: "Manage your studio on DanceCount",
          icon: Icons.check_circle,
          bgColor: Colors.green,
        );
      case 'disabled':
        return _buildStatusContainer(
          title: "Studio Disabled",
          subtitle: "Your studio has been disabled",
          icon: Icons.block,
          bgColor: Colors.red,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required MaterialColor bgColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bgColor.withOpacity(0.3)),
      ),
      child: _buildListTile(
        title,
        icon,
        null,
        subtitle: subtitle,
        color: bgColor.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            "Profile",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshUserData,
              tooltip: 'Refresh Profile',
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 55,
                backgroundColor: Colors.grey[200],
                backgroundImage: _getProfileImage(currentUser.profilePhoto),
                child: _getProfileImage(currentUser.profilePhoto) == null
                    ? const Icon(Icons.person, color: Colors.grey, size: 55)
                    : null,
              ),

              const SizedBox(height: 16),
              Text(
                "${currentUser.firstName} ${currentUser.lastName}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentUser.mobile,
                style: const TextStyle(color: Colors.grey),
              ),
              Text(
                currentUser.email,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle("Account"),
              _buildDropdownTile("Enrolled Batches", buildEnrolledBatches()),
              const Divider(height: 32),

              if (!currentUser.isProfileFullyComplete)
                _buildListTile(
                  "Finish Your Profile",
                  Icons.person_add,
                  _navigateToFinishProfile,
                )
              else
                _buildListTile(
                  "Edit Personal Profile",
                  Icons.edit,
                  _navigateToEditProfile,
                ),

              _buildStudioTile(),

              const Divider(height: 32),
              _buildSectionTitle("Support"),
              _buildListTile(
                "Contact Us",
                null,
                () async {
                  final Uri url = Uri.parse(
                    "https://dancekatta.com/contact-us/",
                  );
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    print("Could not launch $url: $e");
                  }
                },
                customIcon: Image.asset(
                  "assets/icons/contact_us.png",
                  width: 20,
                  height: 20,
                  color: Colors.grey[600],
                ),
              ),

              _buildListTile("Log Out", Icons.logout, _logout),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownTile(String title, Widget content) {
    return Column(
      children: [
        ListTile(
          title: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          trailing: Icon(
            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          ),
          onTap: () {
            setState(() => isExpanded = !isExpanded);
          },
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: content,
          ),
      ],
    );
  }

  Widget _buildListTile(
    String title,
    IconData? icon,
    VoidCallback? onTap, {
    Widget? customIcon,
    Color? color,
    String? subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color ?? Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                customIcon ?? Icon(icon, color: color ?? Colors.grey[600]),
              ],
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  String getFullImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return "";
    if (relativePath.startsWith("http")) return relativePath;
    return "http://147.93.19.17:5002$relativePath";
  }

  ImageProvider? _getProfileImage(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) {
      return null;
    }
    if (relativePath.startsWith('http')) {
      return NetworkImage(relativePath);
    }
    return NetworkImage("http://147.93.19.17:5002$relativePath");
  }
}
