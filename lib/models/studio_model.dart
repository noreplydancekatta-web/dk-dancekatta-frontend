import 'package:mongo_dart/mongo_dart.dart';
import '/constants.dart';

class StudioModel {
  final ObjectId id;
  final dynamic ownerId;

  final String studioName;
  final String registeredAddress;
  final String contactEmail;
  final String contactNumber;
  final String? gstNumber;
  final String panNumber;
  final String? aadharFrontPhoto;
  final String? aadharBackPhoto;
  final String bankAccountNumber;
  final String bankIfscCode;
  final String? studioWebsite;
  final String? studioFacebook;
  final String? studioYoutube;
  final String? studioInstagram;
  final String studioIntroduction;
  final List<String> studioPhotos;
  final String logoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;

  final double averageRating;
  final int totalReviews;

  final double latitude;
  final double longitude;

  final Map<String, dynamic>? ratingBreakdown;

  // NEW optional fields for UI display
  final String? ownerName;
  final int? branchCount;
  final int? batchCount;

  StudioModel({
    required this.id,
    required this.ownerId,
    required this.studioName,
    required this.registeredAddress,
    required this.contactEmail,
    required this.contactNumber,
    this.gstNumber,
    required this.panNumber,
    this.aadharFrontPhoto,
    this.aadharBackPhoto,
    required this.bankAccountNumber,
    required this.bankIfscCode,
    required this.studioIntroduction,
    required this.studioPhotos,
    required this.logoUrl,
    this.studioWebsite,
    this.studioFacebook,
    this.studioYoutube,
    this.studioInstagram,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.averageRating,
    required this.totalReviews,
    this.ratingBreakdown,
    required this.latitude,
    required this.longitude,
    this.ownerName,
    this.branchCount,
    this.batchCount,
  });

  // City getter to extract city from registeredAddress
  String get city {
    final parts = registeredAddress.split(',');
    if (parts.isNotEmpty) {
      return parts.last.trim();
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id.toHexString(),
      'ownerId': ownerId,
      'studioName': studioName,
      'registeredAddress': registeredAddress,
      'contactEmail': contactEmail,
      'contactNumber': contactNumber,
      'gstNumber': gstNumber,
      'panNumber': panNumber,
      'aadharFrontPhoto': aadharFrontPhoto,
      'aadharBackPhoto': aadharBackPhoto,
      'bankAccountNumber': bankAccountNumber,
      'bankIfscCode': bankIfscCode,
      'studioIntroduction': studioIntroduction,
      'studioPhotos': studioPhotos,
      'logoUrl': logoUrl,
      'studioWebsite': studioWebsite,
      'studioFacebook': studioFacebook,
      'studioYoutube': studioYoutube,
      'studioInstagram': studioInstagram,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'ratingBreakdown': ratingBreakdown,
      'latitude': latitude,
      'longitude': longitude,
      if (ownerName != null) 'ownerName': ownerName,
      if (branchCount != null) 'branchCount': branchCount,
      if (batchCount != null) 'batchCount': batchCount,
    };
  }

  factory StudioModel.fromJson(Map<String, dynamic> json) {
    return StudioModel(
      id: ObjectId.parse(json['_id'] as String),
      ownerId: json['ownerId'],
      studioName: json['studioName'] as String? ?? '',
      registeredAddress: json['registeredAddress'] as String? ?? '',
      contactEmail: json['contactEmail'] as String? ?? '',
      contactNumber: json['contactNumber'] as String? ?? '',
      gstNumber: json['gstNumber'] as String?,
      panNumber: json['panNumber'] as String? ?? '',
      aadharFrontPhoto: json['aadharFrontPhoto'] as String? ?? '',
      aadharBackPhoto: json['aadharBackPhoto'] as String? ?? '',
      bankAccountNumber: json['bankAccountNumber'] as String? ?? '',
      bankIfscCode: json['bankIfscCode'] as String? ?? '',
      studioIntroduction: json['studioIntroduction'] as String? ?? '',
      studioPhotos:
          (json['studioPhotos'] as List?)
              ?.map((e) => e as String? ?? '')
              .toList() ??
          [],
      logoUrl: json['logoUrl'] as String? ?? '', // ✅ fallback to empty string
      studioWebsite: json['studioWebsite'] as String?,
      studioFacebook: json['studioFacebook'] as String?,
      studioYoutube: json['studioYoutube'] as String?,
      studioInstagram: json['studioInstagram'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      status: (json['status'] as String?)?.toLowerCase() ?? 'pending',
      averageRating: (json['averageRating'] is num)
          ? (json['averageRating'] as num).toDouble()
          : 0.0,
      totalReviews: (json['totalReviews'] is int)
          ? json['totalReviews'] as int
          : (json['totalReviews'] is num
                ? (json['totalReviews'] as num).toInt()
                : 0),
      ratingBreakdown: json['ratingBreakdown'] != null
          ? Map<String, dynamic>.from(json['ratingBreakdown'])
          : null,
      latitude: (json['latitude'] is num)
          ? (json['latitude'] as num).toDouble()
          : 0.0,
      longitude: (json['longitude'] is num)
          ? (json['longitude'] as num).toDouble()
          : 0.0,
      ownerName: json['ownerName'] as String? ?? 'N/A',
      branchCount: (json['branchCount'] is int)
          ? json['branchCount'] as int
          : (json['branchCount'] is num
                ? (json['branchCount'] as num).toInt()
                : 0),
      batchCount: (json['batchCount'] is int)
          ? json['batchCount'] as int
          : (json['batchCount'] is num
                ? (json['batchCount'] as num).toInt()
                : 0),
    );
  }

  // ✅ Add this copyWith method
  StudioModel copyWith({
    ObjectId? id,
    dynamic ownerId,
    String? studioName,
    String? registeredAddress,
    String? contactEmail,
    String? contactNumber,
    String? gstNumber,
    String? panNumber,
    String? aadharFrontPhoto,
    String? aadharBackPhoto,
    String? bankAccountNumber,
    String? bankIfscCode,
    String? studioWebsite,
    String? studioFacebook,
    String? studioYoutube,
    String? studioInstagram,
    String? studioIntroduction,
    List<String>? studioPhotos,
    String? logoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    double? averageRating,
    int? totalReviews,
    Map<String, dynamic>? ratingBreakdown,
    double? latitude,
    double? longitude,
    String? ownerName,
    int? branchCount,
    int? batchCount,
  }) {
    return StudioModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      studioName: studioName ?? this.studioName,
      registeredAddress: registeredAddress ?? this.registeredAddress,
      contactEmail: contactEmail ?? this.contactEmail,
      contactNumber: contactNumber ?? this.contactNumber,
      gstNumber: gstNumber ?? this.gstNumber,
      panNumber: panNumber ?? this.panNumber,
      aadharFrontPhoto: aadharFrontPhoto ?? this.aadharFrontPhoto,
      aadharBackPhoto: aadharBackPhoto ?? this.aadharBackPhoto,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfscCode: bankIfscCode ?? this.bankIfscCode,
      studioWebsite: studioWebsite ?? this.studioWebsite,
      studioFacebook: studioFacebook ?? this.studioFacebook,
      studioYoutube: studioYoutube ?? this.studioYoutube,
      studioInstagram: studioInstagram ?? this.studioInstagram,
      studioIntroduction: studioIntroduction ?? this.studioIntroduction,
      studioPhotos: studioPhotos ?? this.studioPhotos,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      ratingBreakdown: ratingBreakdown ?? this.ratingBreakdown,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      ownerName: ownerName ?? this.ownerName,
      branchCount: branchCount ?? this.branchCount,
      batchCount: batchCount ?? this.batchCount,
    );
  }
}
