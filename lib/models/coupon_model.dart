class CouponModel {
  final String couponCode;
  final bool isActive;
  final DateTime startDate;
  final DateTime expiryDate;
  final String couponType;
  final String? studioId;
  final int discountPercent;

  CouponModel({
    required this.couponCode,
    required this.isActive,
    required this.startDate,
    required this.expiryDate,
    required this.couponType,
    this.studioId,
    required this.discountPercent,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      couponCode: json['CouponCode']?.toString() ?? '',
      isActive: json['isActive'] ?? false,
      startDate: DateTime.tryParse(json['StartDate'] ?? '') ?? DateTime(2000),
      expiryDate: DateTime.tryParse(json['ExpiryDate'] ?? '') ?? DateTime(2100),
      couponType: json['CouponType']?.toString() ?? 'PlatformWide',
      studioId: json['StudioID']?.toString(),
      discountPercent: (json['DiscountPercent'] ?? 0).toInt(),
    );
  }

  factory CouponModel.empty() => CouponModel(
    couponCode: '',
    isActive: false,
    startDate: DateTime.now(),
    expiryDate: DateTime.now(),
    couponType: 'PlatformWide',
    studioId: null,
    discountPercent: 0,
  );
}
