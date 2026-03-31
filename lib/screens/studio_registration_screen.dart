// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/studio_model.dart';
import '../models/user_model.dart';
import '../database/mongodb_connection.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'studio_success_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../services/upload_service.dart';
import '../constants.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/gestures.dart';
import 'package:mime/mime.dart';

class StudioRegistrationScreen extends StatefulWidget {
  final UserModel user;

  const StudioRegistrationScreen({super.key, required this.user});

  @override
  State<StudioRegistrationScreen> createState() =>
      _StudioRegistrationScreenState();
}

class FirstLetterCapitalizer extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    String text = newValue.text;
    String capitalized = text[0].toUpperCase() + text.substring(1);
    return newValue.copyWith(text: capitalized, selection: newValue.selection);
  }
}

class _StudioRegistrationScreenState extends State<StudioRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  String? _logoPath;
  File? _logoFile;
  final ImagePicker _picker = ImagePicker();

  String? _aadharFrontPath;
  String? _aadharBackPath;
  final List<String> _studioPhotos = [];

  bool _termsAccepted = false;
  bool _isSubmitting = false;
  String? _createdStudioId;

  // ── Upload progress tracking ──────────────────────────────────
  String _uploadStatus = '';
  int _uploadedCount = 0;
  int _totalToUpload = 0;

  final _studioNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankReAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _introductionController = TextEditingController();
  final _websiteController = TextEditingController();
  final _facebookController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _instagramController = TextEditingController();

  // ─────────────────────────────────────────────────────────────
  // 📷 Reusable bottom sheet: Camera or Gallery
  // ─────────────────────────────────────────────────────────────
  Future<ImageSource?> _showImageSourceSheet({
    String title = 'Select Image Source',
  }) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF3A5ED4),
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Take a Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF3A5ED4),
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickSingleImage({
    required String title,
    required void Function(String path) onPicked,
  }) async {
    final source = await _showImageSourceSheet(title: title);
    if (source == null) return;
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) onPicked(image.path);
  }

  Future<void> _pickStudioPhoto() async {
    if (_studioPhotos.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 6 studio photos allowed")),
      );
      return;
    }
    final source = await _showImageSourceSheet(title: 'Add Studio Photo');
    if (source == null) return;
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        if (_studioPhotos.length < 6) _studioPhotos.add(image.path);
      });
    }
  }

  void openTerms() async {
    const url = 'https://dancekatta.com/terms-of-service/';
    if (!await launchUrlString(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  // ─── Validators ───────────────────────────────────────────────
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    if (value.length != 10) return 'Phone number must be 10 digits';
    if (!RegExp(r'^[0-9]+$').hasMatch(value))
      return 'Phone number must contain only digits';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value))
      return 'Please enter a valid email';
    return null;
  }

  String? _validatePAN(String? value) {
    if (value == null || value.isEmpty) return 'PAN number is required';
    if (value.length != 10) return 'PAN number must be 10 characters';
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(value.toUpperCase()))
      return 'PAN format: ABCDE1234F (5 letters + 4 digits + 1 letter)';
    return null;
  }

  String? _validateGST(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.length != 15) return 'GST number must be 15 characters';
    if (!RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
    ).hasMatch(value.toUpperCase()))
      return 'GST format: 22AAAAA0000A1Z5';
    return null;
  }

  String? _validateIFSC(String? value) {
    if (value == null || value.isEmpty) return 'IFSC code is required';
    if (value.length != 11) return 'IFSC code must be 11 characters';
    if (!RegExp(r'^[A-Z]{4}[0-9]{7}$').hasMatch(value.toUpperCase()))
      return 'IFSC format: ABCD0001234 (4 letters + 7 digits)';
    return null;
  }

  String? _validateBankAccount(String? value) {
    if (value == null || value.isEmpty)
      return 'Bank account number is required';
    if (value.length < 9 || value.length > 18)
      return 'Bank account number must be 9-18 digits';
    if (!RegExp(r'^[0-9]+$').hasMatch(value))
      return 'Bank account number must contain only digits';
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  // ─── Navigation ───────────────────────────────────────────────
  Future<void> _registerStudioFirstPage() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ✅ FIX: Upload single image with a longer timeout
  // ─────────────────────────────────────────────────────────────
  Future<String?> _uploadSingle(File file, String url, String fieldName) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
      final parts = mimeType.split('/');

      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          file.path,
          contentType: MediaType(parts[0], parts[1]),
        ),
      );

      // ✅ FIX 1: Added timeout — large images were causing silent hangs
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () =>
            throw Exception('Upload timed out. Check your connection.'),
      );

      final respStr = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        // ✅ FIX 2: Safe JSON decode with clear error message
        dynamic decoded;
        try {
          decoded = jsonDecode(respStr);
        } catch (_) {
          throw Exception('Server returned invalid response: $respStr');
        }

        final path = decoded['path'] as String?;
        if (path == null || path.isEmpty) {
          throw Exception('Server returned empty path for $fieldName');
        }
        return path;
      } else {
        throw Exception(
          'Upload failed (${streamedResponse.statusCode}): $respStr',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ✅ FIX: Upload multiple images ONE BY ONE (not all at once)
  //
  // ROOT CAUSE OF YOUR ERROR:
  //   The original code sent all 6 images in a single multipart
  //   request. With 6 photos this easily exceeds server body limits
  //   (default ~10MB on most Node/Express setups) OR causes a
  //   timeout, resulting in an unhandled exception.
  //
  // THE FIX:
  //   Upload each photo individually and collect all returned paths.
  //   This is more reliable, shows progress, and avoids body-size
  //   limits entirely.
  // ─────────────────────────────────────────────────────────────
  Future<List<String>> _uploadStudioPhotosOneByOne(List<File> files) async {
    final List<String> uploadedPaths = [];

    setState(() {
      _totalToUpload = files.length;
      _uploadedCount = 0;
      _uploadStatus = 'Uploading photo 1 of ${files.length}...';
    });

    for (int i = 0; i < files.length; i++) {
      setState(() {
        _uploadStatus = 'Uploading photo ${i + 1} of ${files.length}...';
      });

      final path = await _uploadSingle(
        files[i],
        "http://147.93.19.17:5002/api/studios/images",
        "image",
      );

      if (path == null || path.isEmpty) {
        throw Exception(
          'Photo ${i + 1} upload failed — server returned empty path',
        );
      }

      uploadedPaths.add(path);

      setState(() {
        _uploadedCount = i + 1;
      });
    }

    return uploadedPaths;
  }

  // ─── Submit ───────────────────────────────────────────────────
  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ── Pre-submit validations ─────────────────────────────────
    if (_logoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a studio logo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_aadharFrontPath == null || _aadharBackPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both Aadhaar front and back photos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_studioPhotos.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least 5 studio photos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadStatus = 'Getting location...';
    });

    try {
      // ── Location ───────────────────────────────────────────────
      Position position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Location timed out. Please enable GPS.'),
          );

      final ownerId = widget.user.id ?? '';

      // ── Upload Logo ────────────────────────────────────────────
      setState(() => _uploadStatus = 'Uploading logo...');
      final logoPath = await _uploadSingle(
        File(_logoFile!.path),
        "http://147.93.19.17:5002/api/studios/logo",
        "image",
      );
      if (logoPath == null)
        throw Exception("Logo upload failed — server returned empty path");

      // ── Upload Aadhaar Front ───────────────────────────────────
      setState(() => _uploadStatus = 'Uploading Aadhaar front...');
      final aadharFrontPath = await _uploadSingle(
        File(_aadharFrontPath!),
        "http://147.93.19.17:5002/api/studios/aadhar-front",
        "image",
      );
      if (aadharFrontPath == null)
        throw Exception("Aadhaar front upload failed");

      // ── Upload Aadhaar Back ────────────────────────────────────
      setState(() => _uploadStatus = 'Uploading Aadhaar back...');
      final aadharBackPath = await _uploadSingle(
        File(_aadharBackPath!),
        "http://147.93.19.17:5002/api/studios/aadhar-back",
        "image",
      );
      if (aadharBackPath == null) throw Exception("Aadhaar back upload failed");

      // ── Upload Studio Photos one by one ───────────────────────
      // ✅ THIS IS THE KEY FIX — was previously one big multipart request
      final studioPhotoPaths = await _uploadStudioPhotosOneByOne(
        _studioPhotos.map((p) => File(p)).toList(),
      );

      if (studioPhotoPaths.length < 5) {
        throw Exception(
          "Only ${studioPhotoPaths.length} studio photos uploaded. Need at least 5.",
        );
      }

      // ── Build payload & register ───────────────────────────────
      setState(() => _uploadStatus = 'Registering studio...');

      final studioData = {
        "ownerId": ownerId,
        "studioName": _studioNameController.text,
        "registeredAddress": _addressController.text,
        "contactEmail": _emailController.text,
        "contactNumber": _phoneController.text,
        "gstNumber": _gstController.text.isEmpty ? null : _gstController.text,
        "panNumber": _panController.text,
        "bankAccountNumber": _bankAccountController.text,
        "bankIfscCode": _bankIfscController.text,
        "studioIntroduction": _introductionController.text,
        "studioWebsite": _websiteController.text,
        "studioFacebook": _facebookController.text,
        "studioYoutube": _youtubeController.text,
        "studioInstagram": _instagramController.text,
        "logoUrl": logoPath,
        "aadharFrontPhoto": aadharFrontPath,
        "aadharBackPhoto": aadharBackPath,
        "studioPhotos": studioPhotoPaths,
        "createdAt": DateTime.now().toIso8601String(),
        "updatedAt": DateTime.now().toIso8601String(),
        "status": "Pending",
        "averageRating": 0.0,
        "totalReviews": 0,
        "latitude": position.latitude.toString(),
        "longitude": position.longitude.toString(),
      };

      final response = await http
          .post(
            Uri.parse('http://147.93.19.17:5002/api/studios'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(studioData),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Registration request timed out'),
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Studio registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StudioSuccessScreen(user: widget.user),
          ),
        );
      } else {
        // ✅ FIX 3: Show actual server error message instead of raw body
        dynamic errBody;
        try {
          errBody = jsonDecode(response.body);
        } catch (_) {
          errBody = {'message': response.body};
        }
        final msg =
            errBody['message'] ??
            errBody['error'] ??
            'Unknown error from server';
        throw Exception('Registration failed: $msg');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
        _uploadStatus = '';
        _uploadedCount = 0;
        _totalToUpload = 0;
      });
    }
  }

  // ─── Helper widgets ───────────────────────────────────────────
  Widget _labeledField(String label, bool required, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        field,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _photoPickerBox({
    required String? imagePath,
    required String label,
    required VoidCallback onTap,
    double height = 100,
    double? width,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: imagePath == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo, size: 30, color: Colors.grey),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(imagePath), fit: BoxFit.cover),
              ),
      ),
    );
  }

  // ─── Upload progress banner ───────────────────────────────────
  Widget _buildUploadProgressBanner() {
    if (!_isSubmitting || _uploadStatus.isEmpty) return const SizedBox.shrink();

    final bool showProgress = _totalToUpload > 0;
    final double progress = showProgress ? _uploadedCount / _totalToUpload : 0;

    return Container(
      width: double.infinity,
      color: const Color(0xFF3A5ED4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _uploadStatus,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          if (showProgress) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_uploadedCount / $_totalToUpload photos uploaded',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ] else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // ✅ Progress banner shown at top during upload
      bottomNavigationBar: _buildUploadProgressBanner(),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // ══════════════════════════════════════════
              // PAGE 1 – Studio details
              // ══════════════════════════════════════════
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: 20,
                        bottom: 40,
                        left: 24,
                        right: 24,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3A5ED4),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () => Navigator.pop(context),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Create Studio Profile',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Welcome to',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Dance Katta',
                            style: GoogleFonts.robotoSlab(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Fill in the details mentioned',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create a Studio profile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _labeledField(
                            'Studio Name',
                            true,
                            TextFormField(
                              controller: _studioNameController,
                              textCapitalization: TextCapitalization.sentences,
                              inputFormatters: [FirstLetterCapitalizer()],
                              decoration: const InputDecoration(
                                hintText: 'Enter studio name here',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  _validateRequired(v, 'Studio Name'),
                            ),
                          ),
                          _labeledField(
                            'Registered Address',
                            true,
                            TextFormField(
                              controller: _addressController,
                              textCapitalization: TextCapitalization.sentences,
                              inputFormatters: [FirstLetterCapitalizer()],
                              decoration: const InputDecoration(
                                hintText: 'Enter registered address',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  _validateRequired(v, 'Registered Address'),
                              maxLines: 3,
                            ),
                          ),
                          _labeledField(
                            'Official Contact Email ID',
                            true,
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                hintText: 'Enter email ID here',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateEmail,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          _labeledField(
                            'Official Contact Number',
                            true,
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                hintText: 'Enter number here',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validatePhoneNumber,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              maxLength: 10,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          _labeledField(
                            'GST Registration Number (Optional)',
                            false,
                            TextFormField(
                              controller: _gstController,
                              decoration: const InputDecoration(
                                hintText: 'Enter GST registration number',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateGST,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]'),
                                ),
                              ],
                              maxLength: 15,
                              textInputAction: TextInputAction.next,
                            ),
                          ),

                          const SizedBox(height: 8),
                          const Text(
                            'KYC Details of Studio Owner',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          _labeledField(
                            'PAN Number of Owner',
                            true,
                            TextFormField(
                              controller: _panController,
                              decoration: const InputDecoration(
                                hintText: 'Enter PAN',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validatePAN,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]'),
                                ),
                              ],
                              maxLength: 10,
                              textInputAction: TextInputAction.next,
                            ),
                          ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Text(
                                    'Aadhaar Card of Owner',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    ' *',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Upload front and back of your Aadhaar card',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _photoPickerBox(
                                      imagePath: _aadharFrontPath,
                                      label: 'Front',
                                      onTap: () => _pickSingleImage(
                                        title: 'Aadhaar Front',
                                        onPicked: (path) => setState(
                                          () => _aadharFrontPath = path,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _photoPickerBox(
                                      imagePath: _aadharBackPath,
                                      label: 'Back',
                                      onTap: () => _pickSingleImage(
                                        title: 'Aadhaar Back',
                                        onPicked: (path) => setState(
                                          () => _aadharBackPath = path,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),

                          const SizedBox(height: 8),
                          const Text(
                            'Bank Details of Studio',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          _labeledField(
                            'Bank Account Number',
                            true,
                            TextFormField(
                              controller: _bankAccountController,
                              decoration: const InputDecoration(
                                hintText: 'Enter bank account number',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateBankAccount,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              maxLength: 18,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          _labeledField(
                            'Re-enter Bank Account Number',
                            true,
                            TextFormField(
                              controller: _bankReAccountController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: 'Re-enter bank account number',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v != _bankAccountController.text
                                  ? 'Account numbers do not match'
                                  : null,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              maxLength: 18,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          _labeledField(
                            'Enter Bank IFS Code',
                            true,
                            TextFormField(
                              controller: _bankIfscController,
                              decoration: const InputDecoration(
                                hintText: 'Enter IFSC code',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateIFSC,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]'),
                                ),
                              ],
                              maxLength: 11,
                              textInputAction: TextInputAction.next,
                            ),
                          ),

                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : _registerStudioFirstPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Next',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ══════════════════════════════════════════
              // PAGE 2 – Logo, Studio Photos & Links
              // ══════════════════════════════════════════
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(
                            top: 60,
                            bottom: 40,
                            left: 24,
                            right: 24,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF3A5ED4),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 1),
                              Text(
                                'Welcome to',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Dance Katta',
                                style: GoogleFonts.robotoSlab(
                                  fontSize: 32,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Fill in the details mentioned',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: -1,
                          left: -1,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () => _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  ),
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create a Studio profile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: const [
                              Text(
                                'Upload Logo',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'PNG / JPEG / JPG  •  Max size: 2 MB',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _photoPickerBox(
                            imagePath: _logoFile?.path,
                            label: 'Logo',
                            width: 100,
                            onTap: () => _pickSingleImage(
                              title: 'Studio Logo',
                              onPicked: (path) =>
                                  setState(() => _logoFile = File(path)),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Row(
                            children: const [
                              Text(
                                'Upload Studio Photos (Min 5)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Only PNG / JPEG / JPG  •  Max size: 2 MB per photo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ✅ Photo count indicator
                          Row(
                            children: [
                              Text(
                                '${_studioPhotos.length} / 6 photos added',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _studioPhotos.length >= 5
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_studioPhotos.length < 5)
                                const Text(
                                  '  (minimum 5 required)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _studioPhotos.length < 6
                                ? _studioPhotos.length + 1
                                : 6,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemBuilder: (context, index) {
                              if (index < _studioPhotos.length) {
                                final photo = _studioPhotos[index];
                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: photo.startsWith("http")
                                            ? Image.network(
                                                photo,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.file(
                                                File(photo),
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: _isSubmitting
                                            ? null
                                            : () => setState(
                                                () => _studioPhotos.removeAt(
                                                  index,
                                                ),
                                              ),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black54,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return GestureDetector(
                                onTap: _isSubmitting ? null : _pickStudioPhoto,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo,
                                        color: Colors.grey,
                                        size: 28,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Add Photo',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          _labeledField(
                            'Studio Introduction',
                            true,
                            TextFormField(
                              controller: _introductionController,
                              textCapitalization: TextCapitalization.sentences,
                              inputFormatters: [FirstLetterCapitalizer()],
                              maxLines: 5,
                              maxLength: 500,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  _validateRequired(v, 'Studio Introduction'),
                              textInputAction: TextInputAction.newline,
                            ),
                          ),
                          _labeledField(
                            'Studio Website',
                            false,
                            TextFormField(
                              controller: _websiteController,
                              decoration: const InputDecoration(
                                hintText:
                                    'Enter studio website (e.g. www.mystudio.com)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                if (!v.contains('.'))
                                  return 'Please enter a valid website URL';
                                return null;
                              },
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          _labeledField(
                            'Studio Facebook Page',
                            false,
                            TextFormField(
                              controller: _facebookController,
                              decoration: const InputDecoration(
                                hintText: 'Enter Facebook page link',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                if (!v.toLowerCase().contains('facebook'))
                                  return 'Please enter a valid Facebook URL';
                                return null;
                              },
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          _labeledField(
                            'Studio YouTube Page',
                            false,
                            TextFormField(
                              controller: _youtubeController,
                              decoration: const InputDecoration(
                                hintText: 'Enter YouTube channel/link',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                if (!v.toLowerCase().contains('youtube'))
                                  return 'Please enter a valid YouTube URL';
                                return null;
                              },
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          _labeledField(
                            'Studio Instagram Page',
                            false,
                            TextFormField(
                              controller: _instagramController,
                              decoration: const InputDecoration(
                                hintText: 'Enter Instagram profile link',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                if (!v.toLowerCase().contains('instagram'))
                                  return 'Please enter a valid Instagram URL';
                                return null;
                              },
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.done,
                            ),
                          ),

                          const SizedBox(height: 24),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _termsAccepted,
                                onChanged: _isSubmitting
                                    ? null
                                    : (val) => setState(
                                        () => _termsAccepted = val ?? false,
                                      ),
                              ),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'I have read and accepted the ',
                                      ),
                                      TextSpan(
                                        text: 'terms & conditions',
                                        style: const TextStyle(
                                          color: Color(0xFF2563EB),
                                          decoration: TextDecoration.underline,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = openTerms,
                                      ),
                                      const TextSpan(
                                        text:
                                            ' of Dance Katta, Dance Mate and Dance Count',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (!_termsAccepted || _isSubmitting)
                                  ? null
                                  : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    (_termsAccepted && !_isSubmitting)
                                    ? const Color(0xFF2563EB)
                                    : Colors.grey.shade400,
                                foregroundColor:
                                    (_termsAccepted && !_isSubmitting)
                                    ? Colors.white
                                    : Colors.white70,
                                elevation: (_termsAccepted && !_isSubmitting)
                                    ? 4
                                    : 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Submit Studio Profile',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _studioNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _gstController.dispose();
    _panController.dispose();
    _bankAccountController.dispose();
    _bankReAccountController.dispose();
    _bankIfscController.dispose();
    _introductionController.dispose();
    _websiteController.dispose();
    _facebookController.dispose();
    _youtubeController.dispose();
    _instagramController.dispose();
    super.dispose();
  }
}
