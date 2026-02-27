import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';

class RazorpayService {
  static const String baseUrl = 'http://147.93.19.17:5004'; // Your actual IP
  // static const String baseUrl = 'http://localhost:5002'; // For web/desktop
  // static const String baseUrl = 'https://your-vps-domain.com'; // For production

  late Razorpay _razorpay;
  Function(PaymentSuccessResponse)? onSuccess;
  Function(PaymentFailureResponse)? onError;

  RazorpayService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    onError?.call(response);
  }

  Future<Map<String, dynamic>> createOrder(double amount) async {
    try {
      print('Sending request to: $baseUrl/create-order');
      print('Request body: ${jsonEncode({'amount': amount})}');

      final response = await http.post(
        Uri.parse('$baseUrl/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': amount}),
      ).timeout(Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Server error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Create order error: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    String? studentId,
    String? batchId,
    String? studioName,
    String? userEmail,
    double? amount,
    String? couponCode,
    double? discountAmount,
    double? discountPercent,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
          'studentId': studentId,
          'batchId': batchId,
          'studioName': studioName,
          'userEmail': userEmail,
          'amount': amount,
          'couponCode': couponCode,
          'discountAmount': discountAmount,
          'discountPercent': discountPercent,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void startPayment({
    required String orderId,
    required double amount,
    required String keyId,
    String? name,
    String? email,
    String? contact,
  }) {
    var options = {
      'key': keyId,
      'amount': (amount * 100).toInt(),
      'name': name ?? 'DanceKatta',
      'order_id': orderId,
      'description': 'Payment for DanceKatta services',
      'prefill': {
        'contact': contact ?? '',
        'email': email ?? '',
      },
      'theme': {
        'color': '#3A5ED4'
      }
    };

    _razorpay.open(options);
  }

  void dispose() {
    _razorpay.clear();
  }
}