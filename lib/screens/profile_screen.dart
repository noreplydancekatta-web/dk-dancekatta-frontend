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
import 'package:flutter/services.dart'; // Added for potential missing imports
import '../services/session_manager.dart';
import '../screens/batch_detail_screen.dart';
import '../models/batch_model.dart';
import '../models/branch_model.dart';

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
  Map<String, dynamic>? studio;
  Map<String, dynamic>? platformFeeData;

  // Current user data (can be updated from finish profile screen)
  late UserModel currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
    _refreshUserData();
    fetchEnrolledBatches();
    fetchPlatformFee();
    // fetchStudio(batch['studioId']);
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
        });
      }
    }
  }

  Future<void> _navigateToFinishProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FinishProfileScreen(user: currentUser)),
    );

    // If we get back updated user data, update the current user
    if (result is UserModel) {
      setState(() {
        currentUser = result;
      });
      // Return updated user to previous screen (HomeScreen)
      Navigator.pop(context, currentUser);
      return;
    } else {
      // Refresh user data after editing
      await _refreshUserData();
    }
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: currentUser)),
    );

    // If we get back updated user data, update the current user
    if (result is UserModel) {
      setState(() {
        currentUser = result;
      });
      // Return updated user to previous screen (HomeScreen)
      Navigator.pop(context, currentUser);
      return;
    } else {
      // Refresh user data after editing
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

    // Refresh user data after studio registration
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
        // ✅ Clear session using SessionManager
        await SessionManager.clearSession();

        // Navigate to login screen and clear navigation stack
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error during logout. Please try again.'),
          ),
        );
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

  Future<Map<String, dynamic>> fetchOwner(String ownerId) async {
    final response = await http.get(
      Uri.parse('http://147.93.19.17:5002/api/users/$ownerId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch owner');
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
    // Fetch owner if not provided
    if (owner == null && studio != null) {
      owner = await fetchOwner(studio['ownerId']); // your async function
    }

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
    final DateTime fromDate = DateTime.tryParse(txn['fromDate'] ?? '') ?? now;
    final DateTime toDate = DateTime.tryParse(txn['toDate'] ?? '') ?? now;

    // ✅ Use backend values with safe parsing
    final double tutorFee = _parseDouble(txn['fee']);
    final double discountAmount = _parseDouble(txn['discountAmount']);
    print('DEBUG: discountAmount = $discountAmount');
    final double discountedTutorFee = tutorFee - discountAmount;

    // ✅ Use values from backend transaction (already set when txn was created)
    final double platformPercent = _parseDouble(
      platformFeeData?['feePercent'],
      0,
    );
    final double gstPercent = _parseDouble(platformFeeData?['gstPercent'], 0);

    // Calculate platform/convenience fee and GST
    final double platformFee = (discountedTutorFee * platformPercent) / 100;
    final double gstOnPlatformFee = (platformFee * gstPercent) / 100;

    final double expectedTotal = tutorFee + platformFee + gstOnPlatformFee;

    // Total fee including platform fee and GST
    final double totalFee = discountedTutorFee + platformFee + gstOnPlatformFee;

    // Amount paid (fallback to totalFee if not provided)
    final double totalAmountPaid = _parseDouble(txn['paymentAmount'], totalFee);

    final String? couponCode = txn['couponCode'] as String?;

    final DateTime paymentDate = txn['paymentDate'] != null
        ? DateTime.tryParse(txn['paymentDate']) ?? now
        : now;

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
              // 🔹 Header
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
                      // pw.Text(
                      //   'Payment Date: ${paymentDate.day}-${paymentDate.month}-${paymentDate.year}',
                      //   style: pw.TextStyle(fontSize: 10),
                      // ),
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
                        // 👇 Mobile number added
                        currentUser.mobile ?? 'N/A',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),

              // 🔹 Table Header
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

              // 🔹 Table Row
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

              // 🔹 Summary
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
                              'Discount (- ₹${discountAmount.toStringAsFixed(2)} '
                              '(${((discountAmount / tutorFee) * 100).round()}%))',
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
                          pw.Text(
                            'GST on Platform Fee ${gstPercent.toStringAsFixed(0)}%',
                          ),
                          pw.Text('₹${gstOnPlatformFee.toStringAsFixed(2)}'),
                        ],
                      ),

                      // pw.Row(
                      //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      //   children: [
                      //     pw.Text('Total Amount Paid',),
                      //     pw.Text('₹${totalAmountPaid.toStringAsFixed(2)}',),
                      //   ],
                      // ),
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

              // 🔹 Payment Info
              pw.SizedBox(height: 20),
              pw.Text(
                'PAYMENTS',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '₹${totalAmountPaid.toStringAsFixed(2)} was paid on ${paymentDate.day}-${paymentDate.month}-${paymentDate.year} via ${txn['paymentMethod'] ?? 'Online'}',
                style: pw.TextStyle(fontSize: 10),
              ),

              // 🔹 Discount Info
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

              // 🔹 Notes
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
        final isEnded =
            DateTime.tryParse(
              batch['toDate'] ?? '',
            )?.isBefore(DateTime.now()) ??
            false;
        final statusText = isEnded ? 'Ended' : 'Active';

        return GestureDetector(
          onTap: () async {
            // ✅ Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  const Center(child: CircularProgressIndicator()),
            );

            try {
              final response = await http.get(
                Uri.parse('$baseUrl/api/batches/${batch['batchId']}'),
              );

              // ✅ Close loading dialog
              Navigator.pop(context);

              if (response.statusCode == 200) {
                final batchData = jsonDecode(response.body);
                final batchModel = BatchModel.fromJson(batchData);

                final branchModel = BranchModel(
                  id: batchModel.branch,
                  name: batch['branchName'] ?? 'Unknown Branch',
                  address: batch['branchAddress'] ?? 'Address not available',
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
                // ✅ Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to load batch details'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } catch (e) {
              // ✅ Close loading dialog
              Navigator.pop(context);

              // ✅ Show error message
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
                      "${batch['style']} • ${batch['level']}",
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
                Text("Payment Successful ₹${batch['paymentAmount'] ?? '0'}/-"),
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
                                    submitRating(
                                      batch['studioId'].toString(),
                                      batch['batchId'].toString(),
                                      rating,
                                    );
                                  },
                                )
                        : const SizedBox(),
                    IconButton(
                      icon: const Icon(Icons.download, size: 22),
                      onPressed: () async {
                        final studioData = await fetchStudioById(
                          batch['studioId'],
                        );
                        await generateInvoice(
                          batch,
                          currentUser,
                          studioData,
                          null,
                        );
                        // pass null for owner for now
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

  @override
  Widget build(BuildContext context) {
    print("Studio Status from ProfileScreen: ${currentUser.studioStatus}");
    print("Is Professional: ${currentUser.isProfessionalChoreographer}");
    return Scaffold(
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              currentUser.mobile,
              style: const TextStyle(color: Colors.grey),
            ),
            Text(currentUser.email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            _buildSectionTitle("Account"),
            _buildDropdownTile("Enrolled Batches", buildEnrolledBatches()),
            const Divider(height: 32),

            // Show different options based on profile completion
            if (!currentUser.isProfileFullyComplete) ...[
              _buildListTile(
                "Finish Your Profile",
                Icons.person_add,
                _navigateToFinishProfile,
              ),
            ] else ...[
              _buildListTile(
                "Edit Personal Profile",
                Icons.edit,
                _navigateToEditProfile,
              ),
            ],

            // 🟢 FIXED: Studio-related options with comprehensive handling
            ...(() {
              // Debug information
              print("════════════════════════════════════════");
              print("🔍 STUDIO STATUS DEBUG:");
              print(
                "  • Profile Complete: ${currentUser.isProfileFullyComplete}",
              );
              print(
                "  • Is Professional: ${currentUser.isProfessionalChoreographer}",
              );
              print("  • Studio Status (raw): '${currentUser.studioStatus}'");
              print(
                "  • Studio Status type: ${currentUser.studioStatus.runtimeType}",
              );

              // Check if professional choreographer
              if (currentUser.isProfessionalChoreographer != true) {
                print("  ❌ Not a professional choreographer");
                print("════════════════════════════════════════");
                return <Widget>[];
              }

              // Check if profile is complete
              if (!currentUser.isProfileFullyComplete) {
                print("  ❌ Profile not fully complete");
                print("════════════════════════════════════════");
                return <Widget>[];
              }

              // Get and process studio status
              final rawStatus = currentUser.studioStatus;

              // If studio not created yet
              if (rawStatus == null || rawStatus.trim().isEmpty) {
                print("  ✅ No studio found - Showing 'Create Studio Profile'");
                print("════════════════════════════════════════");

                return [
                  _buildListTile(
                    "Create Studio Profile",
                    Icons.add_business,
                    _navigateToStudioRegistration,
                  ),
                ];
              }

              // Process status: trim and convert to lowercase
              final status = rawStatus.trim().toLowerCase();
              print("  • Processed Status: '$status'");

              // Check for "pending" status (case-insensitive)
              if (status == 'pending') {
                print("  ✅ MATCH: Showing 'Studio Under Review'");
                print("════════════════════════════════════════");
                return [
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: _buildListTile(
                      "Studio Under Review",
                      Icons.hourglass_top,
                      null,
                      subtitle: "Your studio is under verification",
                      color: Colors.orange.shade700,
                    ),
                  ),
                ];
              }

              // Check for "approved" status (case-insensitive)
              if (status == 'approved') {
                return [
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: _buildListTile(
                      "Studio Approved",
                      Icons.check_circle,
                      null, // ✅ No onTap → Not clickable
                      subtitle: "Manage your studio on DanceCount",
                      color: Colors.green.shade700,
                    ),
                  ),
                ];
              }
              // Check for "rejected" status
              if (status == 'rejected') {
                print("  ⚠️ MATCH: Studio REJECTED - showing nothing");
                print("════════════════════════════════════════");
                return <Widget>[];
              }

              // Unknown status
              print("  ⚠️ UNKNOWN Status: '$status' - showing nothing");
              print("════════════════════════════════════════");
              return <Widget>[];
            })(),

            const Divider(height: 32),
            _buildSectionTitle("Support"),
            _buildListTile(
              "Contact Us",
              null,
              () async {
                final Uri url = Uri.parse("https://dancekatta.com/contact-us/");
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (e) {
                  print("❌ Could not launch $url: $e");
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
    VoidCallback? onTap, { // make onTap nullable to allow disabling
    Widget? customIcon,
    Color? color,
    String? subtitle, // new parameter
  }) {
    return InkWell(
      onTap: onTap, // if null, tile is disabled
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

  /// Helper to build full URL for uploaded images
  String getFullImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return "";
    if (relativePath.startsWith("http")) return relativePath;
    return "http://147.93.19.17:5002$relativePath"; // ✅ keep same as edit_profile
  }

  /// Returns an ImageProvider for the profile image
  ImageProvider? _getProfileImage(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) {
      return null; // no image, CircleAvatar will show the child
    }

    // If already a full URL (e.g., from social login or testing)
    if (relativePath.startsWith('http')) {
      return NetworkImage(relativePath);
    }

    // Otherwise, treat as relative path from backend
    return NetworkImage("http://147.93.19.17:5002$relativePath");
  }
}
