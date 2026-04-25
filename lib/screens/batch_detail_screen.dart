import 'dart:io';
import 'package:dancekatta/models/branch_model.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/batch_model.dart';
import '../models/coupon_model.dart';
import '../models/platform_fee_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/upload_service.dart';
import '../constants.dart';
import '../services/razorpay_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class BatchDetailScreen extends StatefulWidget {
  final BatchModel batch;
  final BranchModel branch;
  final VoidCallback? onEnrollmentUpdate;

  const BatchDetailScreen({
    super.key,
    required this.batch,
    required this.branch,
    this.onEnrollmentUpdate,
  });

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  final TextEditingController _couponController = TextEditingController();
  String? couponError;
  int discountAmount = 0;
  PlatformFeeModel? platformFee;
  bool isLoadingFee = true;
  String? loggedInUserId;
  String? studioName;
  double studioRating = 0.0;
  int studioReviews = 0;
  bool isLoadingStudio = true;
  bool isBatchDeleted = false;
  bool isStudioDeleted = false;

  Map<String, dynamic>? transaction;
  bool isLoadingTransaction = true;

  BranchModel? actualBranch;
  bool isLoadingBranch = true;
  String trainerName = 'Unknown Trainer';
  late BatchModel currentBatch;

  Map<String, dynamic>? studio;

  @override
  void initState() {
    super.initState();
    currentBatch = widget.batch;

    refreshBatch();
    fetchPlatformFee();
    getLoggedInUserId();
    fetchBranchData();
    _fetchStudio();
    setTrainerName();

    _couponController.addListener(() {
      if (_couponController.text.trim().isEmpty && discountAmount != 0) {
        setState(() {
          discountAmount = 0;
          couponError = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudio() async {
    if (widget.batch.studioId == null || widget.batch.studioId!.isEmpty) {
      _handleStudioDeleted();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'http://147.93.19.17:5002/api/studios/${widget.batch.studioId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          studio = data;
          studioName = data['studioName'] ?? 'Studio';
          studioRating = (data['averageRating'] ?? 0).toDouble();
          studioReviews = data['totalReviews'] ?? 0;
          isLoadingStudio = false;
        });
      } else {
        _handleStudioDeleted();
      }
    } catch (_) {
      _handleStudioDeleted();
    }
  }

  void _handleStudioDeleted() {
    if (!mounted) return;
    setState(() {
      isStudioDeleted = true;
      isLoadingStudio = false;
    });
  }

  Future<void> getLoggedInUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('userId');
    setState(() {
      loggedInUserId = id;
    });
    debugPrint("📦 Proceed to enroll with userId: $loggedInUserId");
    await fetchTransaction();
  }

  Future<void> refreshEnrollment() async {
    await fetchTransaction();
    await refreshBatch();
    setState(() {});
  }

  Future<void> fetchTransaction() async {
    if (loggedInUserId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          "http://147.93.19.17:5002/api/transactions/enrolled/$loggedInUserId",
        ),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        transaction = data.cast<Map<String, dynamic>>().firstWhere((txn) {
          final txnBatchId = txn['batchId'] is Map
              ? txn['batchId']['_id']
              : txn['batchId'];

          return txnBatchId == widget.batch.id;
        }, orElse: () => {});

        if (transaction!.isEmpty) {
          transaction = null;
        }
      }
    } catch (e) {
      print('Error fetching transaction: $e');
    }

    setState(() => isLoadingTransaction = false);
  }

  Future<void> fetchPlatformFee() async {
    try {
      final response = await http.get(
        Uri.parse('http://147.93.19.17:5002/api/platformfees'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        setState(() {
          if (data.isNotEmpty) {
            platformFee = PlatformFeeModel.fromJson(data.last);
          } else {
            platformFee = PlatformFeeModel(
              id: 'fallback',
              feePercent: 5,
              gstPercent: 18,
            );
          }
          isLoadingFee = false;
        });
      } else {
        _fallbackPlatformFee();
      }
    } catch (e) {
      debugPrint('❌ Platform fee error: $e');
      _fallbackPlatformFee();
    }
  }

  void _fallbackPlatformFee() {
    setState(() {
      platformFee = PlatformFeeModel(
        id: 'fallback',
        feePercent: 5,
        gstPercent: 18,
      );
      isLoadingFee = false;
    });
  }

  Future<void> fetchBranchData() async {
    if (widget.batch.branch.isEmpty) {
      setState(() {
        actualBranch = widget.branch;
        isLoadingBranch = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'http://147.93.19.17:5002/api/branches/${widget.batch.branch}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          actualBranch = BranchModel.fromJson(data);
          isLoadingBranch = false;
        });
      } else {
        setState(() {
          actualBranch = BranchModel(
            id: '',
            name: 'Branch Deleted',
            address: 'Address not available',
            area: 'N/A',
            contactNo: 'N/A',
            mapLink: '',
          );
          isLoadingBranch = false;
        });
      }
    } catch (e) {
      setState(() {
        actualBranch = BranchModel(
          id: '',
          name: 'Branch Deleted',
          address: 'Address not available',
          area: 'N/A',
          contactNo: 'N/A',
          mapLink: '',
        );
        isLoadingBranch = false;
      });
    }
  }

  void setTrainerName() {
    if (widget.batch.trainerName != null &&
        widget.batch.trainerName!.trim().isNotEmpty &&
        widget.batch.trainerName!.trim().toLowerCase() != 'unknown') {
      trainerName = widget.batch.trainerName!;
      return;
    }
    if (widget.batch.trainer != null &&
        widget.batch.trainer.trim().isNotEmpty &&
        widget.batch.trainer.trim().toLowerCase() != 'unknown') {
      trainerName = widget.batch.trainer;
      return;
    }
    if (widget.batch.batchData != null &&
        widget.batch.batchData is Map &&
        widget.batch.batchData['trainerName'] != null &&
        widget.batch.batchData['trainerName'].toString().trim().isNotEmpty &&
        widget.batch.batchData['trainerName'].toString().trim().toLowerCase() !=
            'unknown') {
      trainerName = widget.batch.batchData['trainerName'].toString();
      return;
    }
    if (widget.batch.batchData != null &&
        widget.batch.batchData is Map &&
        widget.batch.batchData['trainer'] != null &&
        widget.batch.batchData['trainer'].toString().trim().isNotEmpty &&
        widget.batch.batchData['trainer'].toString().trim().toLowerCase() !=
            'unknown') {
      trainerName = widget.batch.batchData['trainer'].toString();
      return;
    }
    if (widget.batch.trainer is Map) {
      final trainerMap = widget.batch.trainer as Map;
      String name = '';
      if (trainerMap['firstName'] != null)
        name += trainerMap['firstName'].toString();
      if (trainerMap['lastName'] != null)
        name += ' ' + trainerMap['lastName'].toString();
      if (name.trim().isNotEmpty) {
        trainerName = name.trim();
        return;
      }
      if (trainerMap['name'] != null &&
          trainerMap['name'].toString().trim().isNotEmpty) {
        trainerName = trainerMap['name'].toString();
        return;
      }
    }
    trainerName = 'Unknown Trainer';
  }

  Future<void> applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('http://147.93.19.17:5002/api/coupons'),
      );

      if (response.statusCode != 200) {
        setState(() => couponError = "Something went wrong");
        return;
      }

      final List data = jsonDecode(response.body);
      final coupons = data.map((e) => CouponModel.fromJson(e)).toList();

      print('💡 All Coupons from API:');
      for (var c in coupons) {
        print(
          'Code: ${c.couponCode}, Type: ${c.couponType}, Studio: ${c.studioId}, Active: ${c.isActive}, Start: ${c.startDate}, End: ${c.expiryDate}, Discount: ${c.discountPercent}',
        );
      }

      final now = DateTime.now().toUtc();

      final matched = coupons.firstWhere((c) {
        final codeMatch =
            c.couponCode.toLowerCase().trim() == code.toLowerCase().trim();
        final active = c.isActive;

        final start = c.startDate is DateTime
            ? c.startDate.toUtc()
            : DateTime.parse(c.startDate.toString()).toUtc();
        final end = c.expiryDate is DateTime
            ? c.expiryDate.toUtc()
            : DateTime.parse(c.expiryDate.toString()).toUtc();
        final dateValid = !now.isBefore(start) && !now.isAfter(end);

        bool typeValid = false;
        if (c.couponType == 'PlatformWide') {
          typeValid = true;
        } else if (c.couponType == 'StudioSpecific' && c.studioId != null) {
          typeValid =
              c.studioId!.toLowerCase().trim() ==
              widget.batch.studioId?.toLowerCase().trim();
        }

        print(
          '🔹 Checking coupon: ${c.couponCode}, Active: $active, TypeValid: $typeValid, DateValid: $dateValid, StudioId: ${c.studioId}',
        );
        return codeMatch && active && dateValid && typeValid;
      }, orElse: () => CouponModel.empty());

      if (matched.couponCode == '') {
        setState(() {
          couponError = "Invalid or Expired Coupon";
          discountAmount = 0;
        });
      } else {
        final int fee = int.tryParse(widget.batch.fee) ?? 0;
        final calculatedDiscount = ((fee * matched.discountPercent) / 100)
            .floor();

        setState(() {
          couponError = null;
          discountAmount = calculatedDiscount;
        });

        print(
          '✅ Coupon Applied: ${matched.couponCode}, Discount: ₹$calculatedDiscount',
        );
      }
    } catch (e) {
      setState(() => couponError = "Error: $e");
      print('❌ Coupon Error: $e');
    }
  }

  String getLevelName() {
    if (widget.batch.levelName != null && widget.batch.levelName!.isNotEmpty) {
      return widget.batch.levelName!;
    }
    return 'Unknown Level';
  }

  String getBranchName() {
    if (widget.batch.branchName != null &&
        widget.batch.branchName!.isNotEmpty &&
        widget.batch.branchName != 'Unknown Branch' &&
        widget.batch.branchName != 'N/A') {
      return widget.batch.branchName!;
    }

    if (widget.batch.branch is Map) {
      final branchMap = widget.batch.branch as Map;
      if (branchMap['branchName'] != null) {
        return branchMap['branchName'].toString();
      } else if (branchMap['name'] != null) {
        return branchMap['name'].toString();
      }
    }

    if (isLoadingBranch) {
      return 'Loading...';
    }
    if (actualBranch != null &&
        actualBranch!.name.isNotEmpty &&
        actualBranch!.name != 'Unknown Branch') {
      return actualBranch!.name;
    }
    return widget.branch.name;
  }

  String getTrainerName() {
    if (widget.batch.trainer != null &&
        widget.batch.trainer!.trim().isNotEmpty &&
        widget.batch.trainer!.trim().toLowerCase() != 'unknown') {
      return widget.batch.trainer!.trim();
    }

    if (widget.batch.trainerName != null &&
        widget.batch.trainerName!.trim().isNotEmpty &&
        widget.batch.trainerName!.trim().toLowerCase() != 'unknown') {
      return widget.batch.trainerName!.trim();
    }

    if (widget.batch.batchData != null && widget.batch.batchData is Map) {
      final batchMap = widget.batch.batchData as Map;

      if (batchMap['trainer'] != null &&
          batchMap['trainer'].toString().trim().isNotEmpty &&
          batchMap['trainer'].toString().trim().toLowerCase() != 'unknown') {
        return batchMap['trainer'].toString().trim();
      }

      if (batchMap['trainerName'] != null &&
          batchMap['trainerName'].toString().trim().isNotEmpty &&
          batchMap['trainerName'].toString().trim().toLowerCase() !=
              'unknown') {
        return batchMap['trainerName'].toString().trim();
      }
    }

    if (widget.batch.trainer is Map) {
      final trainerMap = widget.batch.trainer as Map;
      String name = '';
      if (trainerMap['firstName'] != null)
        name += trainerMap['firstName'].toString();
      if (trainerMap['lastName'] != null)
        name += ' ' + trainerMap['lastName'].toString();
      if (name.trim().isNotEmpty) return name.trim();
      if (trainerMap['name'] != null &&
          trainerMap['name'].toString().trim().isNotEmpty) {
        return trainerMap['name'].toString().trim();
      }
    }

    return 'Unknown Trainer';
  }

  String getBranchAddress() {
    if (widget.batch.branchAddress != null &&
        widget.batch.branchAddress!.isNotEmpty &&
        widget.batch.branchAddress != 'Address not available' &&
        widget.batch.branchAddress != 'N/A') {
      return widget.batch.branchAddress!;
    }

    if (widget.batch.branch is Map) {
      final branchMap = widget.batch.branch as Map;
      if (branchMap['branchAddress'] != null) {
        return branchMap['branchAddress'].toString();
      } else if (branchMap['address'] != null) {
        return branchMap['address'].toString();
      }
    }

    if (isLoadingBranch) {
      return 'Loading...';
    }
    if (actualBranch != null &&
        actualBranch!.address.isNotEmpty &&
        actualBranch!.address != 'Address not available') {
      return actualBranch!.address;
    }
    return widget.branch.address;
  }

  String getBranchContact() {
    if (widget.batch.branchContactNo != null &&
        widget.batch.branchContactNo!.isNotEmpty &&
        widget.batch.branchContactNo != 'N/A') {
      return widget.batch.branchContactNo!;
    }

    if (isLoadingBranch) {
      return 'Loading...';
    }
    if (actualBranch != null &&
        actualBranch!.contactNo.isNotEmpty &&
        actualBranch!.contactNo != 'Not Available') {
      return actualBranch!.contactNo;
    }
    return widget.branch.contactNo;
  }

  String getBranchMapLink() {
    if (actualBranch != null && actualBranch!.mapLink.isNotEmpty) {
      return actualBranch!.mapLink;
    }
    return widget.branch.mapLink;
  }

  @override
  Widget build(BuildContext context) {
    if (isStudioDeleted || isBatchDeleted) {
      return const Scaffold(
        body: Center(child: Text('Batch no longer available')),
      );
    }

    if (isLoadingFee) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final logoUrl = studio?['logoUrl']?.toString() ?? '';
    final batch = widget.batch;
    int tutorFee = int.tryParse(batch.fee) ?? 0;
    int discountedTutorFee = tutorFee - discountAmount;

    double platformPercent = platformFee?.feePercent ?? 5;
    double gstPercent = platformFee?.gstPercent ?? 18;

    double convenienceFee = (discountedTutorFee * platformPercent) / 100;
    double gst = (convenienceFee * gstPercent) / 100;
    double totalFee = (discountedTutorFee + convenienceFee + gst).roundToDouble();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            batch.batchName,
            style: const TextStyle(color: Colors.black),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),

        // ✅ FLOATING PAY BUTTON - FIXED
        bottomNavigationBar: _buildFloatingPayButton(totalFee),

        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Studio Info Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.grey.shade300,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: logoUrl.isNotEmpty
                          ? Image.network(
                              getFullImageUrl(logoUrl),
                              height: 40,
                              width: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    height: 40,
                                    width: 40,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.store,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                            )
                          : Container(
                              height: 40,
                              width: 40,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.store,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLoadingStudio)
                          const Text(
                            "Loading...",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )
                        else
                          Text(
                            studioName ?? "Studio",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 4),
                        if (isLoadingStudio)
                          const Text(
                            "Loading...",
                            style: TextStyle(color: Colors.green),
                          )
                        else
                          Text(
                            "⭐ ${studioRating.toStringAsFixed(1)} ($studioReviews Reviews)",
                            style: const TextStyle(color: Colors.green),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Batch Details
              Text(
                widget.batch.batchName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow("Level", getLevelName()),
              _buildInfoRow("Trainer", getTrainerName()),
              _buildInfoRow(
                "Dates",
                "${_formatDate(widget.batch.fromDate)} to ${_formatDate(widget.batch.toDate)}",
              ),
              _buildInfoRow(
                "Time",
                "${widget.batch.startTime} - ${widget.batch.endTime}",
              ),

              // Days chips
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 100,
                    child: Text(
                      "Days",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.batch.days
                          .map(
                            (day) => Chip(
                              label: Text(day),
                              backgroundColor: Colors.blue[50],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildInfoRow("Branch", getBranchName()),
              _buildInfoRow(
                "Address",
                getBranchAddress(),
                isLink: true,
                url: getBranchMapLink(),
              ),
              _buildInfoRow("Contact", getBranchContact()),
              _buildInfoRow(
                "Seats",
                "${currentBatch.enrolledStudents.length} out of ${currentBatch.capacity}",
              ),
              const SizedBox(height: 24),

              // Coupon Section
              TextField(
                controller: _couponController,
                decoration: InputDecoration(
                  hintText: "Enter coupon code",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: couponError == null && discountAmount > 0
                          ? Colors.green
                          : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: couponError == null && discountAmount > 0
                          ? Colors.green
                          : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: couponError == null && discountAmount > 0
                          ? Colors.green
                          : Colors.blue,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
              if (couponError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    couponError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: 100,
                height: 42,
                child: ElevatedButton(
                  onPressed: applyCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B0FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Apply",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Fee Breakdown
              const Text(
                "Fee Breakdown",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              _buildFeeItem("Tutor Fee:", "₹$tutorFee"),
              if (discountAmount > 0) ...[
                _buildFeeItem(
                  "Discount (${((discountAmount / tutorFee) * 100).round()}%):",
                  "-₹$discountAmount",
                  color: Colors.green,
                ),
                _buildFeeItem("Fee after Discount:", "₹$discountedTutorFee"),
              ],
              _buildFeeItem(
                "Convenience Fee ($platformPercent%):",
                "₹${convenienceFee.toStringAsFixed(2)}",
              ),
              _buildFeeItem(
                "GST ($gstPercent%):",
                "₹${gst.toStringAsFixed(2)}",
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total Payable:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  Text(
                    "₹${totalFee.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ), // closes Scaffold
    ); // closes PopScope
  }

  // ✅ FLOATING PAY BUTTON
  Widget _buildFloatingPayButton(double totalFee) {
    final isAlreadyEnrolled = transaction != null;
    final isBatchFull =
        currentBatch.enrolledStudents.length >= currentBatch.capacity;
    final isDisabled = isAlreadyEnrolled || isBatchFull;

    String buttonText;
    if (isAlreadyEnrolled) {
      buttonText = 'Already Enrolled';
    } else if (isBatchFull) {
      buttonText = 'Batch Full';
    } else if (totalFee < 1) {
      buttonText = 'Free Enrollment';
    } else {
      buttonText = "Pay  Now";
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ElevatedButton(
            onPressed: isDisabled ? null : () => _handlePayment(totalFee),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDisabled
                  ? Colors.grey
                  : const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
              disabledBackgroundColor: Colors.grey,
              disabledForegroundColor: Colors.white,
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ PAYMENT HANDLER
  Future<void> _handlePayment(double totalFee) async {
    final razorpay = RazorpayService();

    // ✅ Payment success callback
    razorpay.onSuccess = (response) async {
      final roundedAmount = double.parse(totalFee.toStringAsFixed(2));
      final isVerified = await razorpay.verifyPayment(
        orderId: response.orderId!,
        paymentId: response.paymentId!,
        signature: response.signature!,
        studentId: loggedInUserId,
        batchId: currentBatch.id,
        studioName: studioName ?? 'Unknown Studio',
        amount: roundedAmount,
        couponCode: _couponController.text.trim().isEmpty
            ? null
            : _couponController.text.trim(),
        discountAmount: discountAmount.toDouble(),
        discountPercent: discountAmount > 0
            ? ((discountAmount / (int.tryParse(currentBatch.fee) ?? 0)) * 100)
            : 0,
      );

      if (isVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment successful! You have been enrolled. ID: ${response.paymentId}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        await refreshEnrollment();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment verification failed. You have not been enrolled.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    };

    // ❌ Payment error callback
    razorpay.onError = (response) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response.message}'),
          backgroundColor: Colors.red,
        ),
      );
    };

    try {
      final roundedAmount = double.parse(totalFee.toStringAsFixed(2));
      final orderData = await razorpay.createOrder(roundedAmount);
      if (orderData['success']) {
        razorpay.startPayment(
          orderId: orderData['order_id'],
          amount: roundedAmount,
          keyId: orderData['key_id'],
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> refreshBatch() async {
    try {
      print('🔄 Refreshing batch data for ID: ${widget.batch.id}');

      final response = await http.get(
        Uri.parse('http://147.93.19.17:5002/api/batches'),
      );

      print('📡 Batch refresh response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        final batchData = data.cast<Map<String, dynamic>>().firstWhere(
          (b) => b['_id'] == widget.batch.id,
          orElse: () => {},
        );

        if (batchData.isEmpty) {
          setState(() {
            isBatchDeleted = true;
          });

          if (mounted) {
            setState(() {
              isBatchDeleted = true;
            });
          }
          return;
        }

        final newBatch = BatchModel.fromJson(batchData);

        if (mounted) {
          setState(() {
            currentBatch = newBatch;
          });
        }

        print(
          "✅ Updated enrolled students: ${currentBatch.enrolledStudents.length}",
        );
      } else {
        print('❌ Failed to refresh batch list: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error refreshing batch: $e');
    }
  }

  Widget _buildInfoRow(
    String title,
    String value, {
    bool isLink = false,
    String? url,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: isLink && url != null
                ? InkWell(
                    onTap: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeItem(String label, String amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, color: color ?? Colors.black87),
          ),
          Text(
            amount,
            style: TextStyle(fontSize: 16, color: color ?? Colors.black87),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return "${date.day}/${date.month}/${date.year}";
  }
}
