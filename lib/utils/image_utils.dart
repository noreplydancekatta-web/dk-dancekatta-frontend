import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

ImageProvider getImageProvider(String imageSource) {
  if (imageSource.isEmpty) {
    return const NetworkImage('https://via.placeholder.com/150');
  }

  try {
    // ✅ Base64 (starts with "data:image" or very long string)
    if (imageSource.startsWith('data:image') || imageSource.length > 1000) {
      final base64Str = imageSource.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    }

    // ✅ Full Network URL
    if (imageSource.startsWith('http')) {
      return NetworkImage(imageSource);
    }

    // ✅ Local File (e.g., Android cached image path)
    if (imageSource.startsWith('/data/')) {
      return FileImage(File(imageSource));
    }
  } catch (e) {
    debugPrint("Image decode error: $e");
  }

  // ❌ If nothing matches, use fallback placeholder
  return const NetworkImage('https://via.placeholder.com/150');
}