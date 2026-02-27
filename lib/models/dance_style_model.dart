import 'package:flutter/foundation.dart';

class DanceStyleModel {
  final String id;
  final String name;
  final String imageUrl;

  DanceStyleModel({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  /// Allows updating specific fields
  DanceStyleModel copyWith({String? id, String? name, String? imageUrl}) {
    return DanceStyleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// Create model from API JSON
  factory DanceStyleModel.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print(
        "Parsing dance style: ${json['name']} - imageUrl: ${json['imageUrl']}",
      );
    }
    return DanceStyleModel(
      id: json['_id']?.toString() ?? '', // ✅ Safe parse for id
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
    );
  }

  /// Convert to JSON (if you want to save locally)
  Map<String, dynamic> toJson() {
    return {'_id': id, 'name': name, 'imageUrl': imageUrl};
  }
}
