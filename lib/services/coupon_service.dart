import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/coupon_model.dart';

class CouponService {
  static Future<CouponModel?> validateCoupon(String code, String studioId) async {
    final url = Uri.parse("http://147.93.19.17:5002/api/coupons");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        for (var item in data) {
          final coupon = CouponModel.fromJson(item);

          if (coupon.couponCode.toLowerCase() == code.toLowerCase()) {
            final now = DateTime.now();

            // 🔎 Check active flag
            if (!coupon.isActive) return null;

            // 🔎 Check date validity
            if (coupon.startDate.isAfter(now)) return null;   // not started yet
            if (coupon.expiryDate.isBefore(now)) return null; // already expired

            // 🔎 Check type
            if (coupon.couponType == 'PlatformWide') {
              return coupon; // ✅ valid for everyone
            }
            if (coupon.couponType == 'StudioSpecific' && coupon.studioId == studioId) {
              return coupon; // ✅ valid for matching studio
            }

            return null; // coupon exists but not applicable
          }
        }
        return null; // no matching coupon found
      } else {
        throw Exception("Failed to fetch coupons: ${response.statusCode}");
      }
    } catch (e) {
      print('❌ Error validating coupon: $e');
      return null;
    }
  }
}
