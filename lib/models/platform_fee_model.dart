class PlatformFeeModel {
  final String id;
  final double feePercent;
  final double gstPercent;

  PlatformFeeModel({
    required this.id,
    required this.feePercent,
    required this.gstPercent,
  });

  factory PlatformFeeModel.fromJson(Map<String, dynamic> json) {
    return PlatformFeeModel(
      id: json['_id'],
      feePercent: (json['feePercent'] ?? 0).toDouble(),
      gstPercent: (json['gstPercent'] ?? 0).toDouble(),
    );
  }
}