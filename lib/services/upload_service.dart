import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // 👈 add this
import 'package:mime/mime.dart'; // 👈 add this
import '../constants.dart'; // BASE_URL & getFullImageUrl

class UploadService {
  static const String _base = BASE_URL;

  static Future<String> uploadImage(File file, String endpoint) async {
    final uri = Uri.parse('$_base/$endpoint');

    // 👇 detect MIME type (e.g. image/jpeg, image/png)
    final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
    final typeSplit = mimeType.split('/');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        await http.MultipartFile.fromPath(
          'image',
          file.path,
          contentType: MediaType(typeSplit[0], typeSplit[1]), // 👈 fix here
        ),
      );

    final response = await request.send();
    final respStr = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final jsonResp = jsonDecode(respStr);

      if (jsonResp['path'] != null && jsonResp['path'].toString().startsWith('/uploads/')) {
        return jsonResp['path']; // ✅ relative path only
      }
      throw Exception('No valid "path" returned from backend');
    } else {
      throw Exception('Upload failed: ${response.statusCode}, $respStr');
    }
  }

  static String fullUrl(String relativePath) => '$_base$relativePath';
}
