import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/razorpay_service.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String? userEmail;
  final String? userContact;
  final String? userName;
  final String? batchName;
  final String? branchName; // ✅ ADDED
  final String? batchStartDate;
  final String? studentId;
  final String? studentName;
  final String? batchId;
  final String? studioName;

  const PaymentScreen({
    Key? key,
    required this.amount,
    this.userEmail,
    this.userContact,
    this.userName,
    this.batchName,
    this.branchName, // ✅ ADDED
    this.batchStartDate,
    this.studentId,
    this.studentName,
    this.batchId,
    this.studioName,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late RazorpayService _razorpayService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService();
    _razorpayService.onSuccess = _handlePaymentSuccess;
    _razorpayService.onError = _handlePaymentError;
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isLoading = true);

    try {
      final isVerified = await _razorpayService.verifyPayment(
        orderId: response.orderId!,
        paymentId: response.paymentId!,
        signature: response.signature!,
        studentId: widget.studentId ?? '',
        studentName: widget.studentName ?? widget.userName ?? '', // ✅ fallback
        batchId: widget.batchId ?? '',
        batchName: widget.batchName ?? '', // ✅ ADDED
        branchName: widget.branchName ?? '', // ✅ ADDED
        studioName: widget.studioName ?? '',
        userEmail: widget.userEmail ?? '',
        amount: widget.amount,
      );

      setState(() => _isLoading = false);

      if (isVerified) {
        _showSuccessDialog(response.paymentId!);
      } else {
        _showErrorDialog('Payment verification failed');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Verification error: $e');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showErrorDialog('Payment failed: ${response.message}');
  }

  void _startPayment() async {
    setState(() => _isLoading = true);

    try {
      final orderData = await _razorpayService.createOrder(widget.amount);

      if (orderData['success']) {
        setState(() => _isLoading = false);

        _razorpayService.startPayment(
          orderId: orderData['order_id'],
          amount: widget.amount,
          keyId: orderData['key_id'],
          name: widget.userName,
          email: widget.userEmail,
          contact: widget.userContact,
        );
      } else {
        setState(() => _isLoading = false);
        _showErrorDialog('Failed to create order');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Error: $e');
    }
  }

  void _showSuccessDialog(String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        title: const Text('Enrollment Successful! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment ID: $paymentId'),
            const SizedBox(height: 8),
            if (widget.batchName != null) Text('Batch: ${widget.batchName}'),
            if (widget.branchName != null) Text('Branch: ${widget.branchName}'),
            const SizedBox(height: 8),
            if (widget.userEmail != null)
              Text(
                'A confirmation email has been sent to ${widget.userEmail}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error, color: Colors.red, size: 50),
        title: const Text('Payment Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFF3A5ED4),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.payment,
                      size: 60,
                      color: Color(0xFF3A5ED4),
                    ),
                    const SizedBox(height: 20),
                    if (widget.batchName != null) ...[
                      Text(
                        widget.batchName!,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (widget.branchName != null) ...[
                      Text(
                        'Branch: ${widget.branchName!}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Amount to Pay',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '₹${widget.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: const Color(0xFF3A5ED4),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _startPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A5ED4),
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Pay Now',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Secure payment powered by Razorpay',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
