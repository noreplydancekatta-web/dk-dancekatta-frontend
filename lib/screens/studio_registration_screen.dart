// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/studio_model.dart';
import '../models/user_model.dart'; // âœ… Added import
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

    // Capitalize first character only
    String capitalized = text[0].toUpperCase() + text.substring(1);

    return newValue.copyWith(text: capitalized, selection: newValue.selection);
  }
}

class _StudioRegistrationScreenState extends State<StudioRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  String? _logoPath; // will hold relative URL returned by backend
  File? _logoFile;
  final ImagePicker _picker = ImagePicker();
  String? _aadharFrontPath;
  String? _aadharBackPath;
  final List<String> _studioPhotos = [];
  bool _termsAccepted = false;

  // âœ… Add this function here, outside build()
  void openTerms() async {
    const url = 'https://dancekatta.com/terms-of-service/';
    if (!await launchUrlString(
      url,
      mode: LaunchMode.externalApplication, // opens in browser
    )) {
      debugPrint('Could not launch $url');
    }
  }

  bool _isSubmitting = false;
  String? _createdStudioId; // Store studio ID after registration

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

  /// Validate phone number (10 digits)
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length != 10) {
      return 'Phone number must be 10 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Phone number must contain only digits';
    }
    return null;
  }

  /// Validate email format
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Validate PAN number (10 characters: 5 letters + 4 digits + 1 letter)
  String? _validatePAN(String? value) {
    if (value == null || value.isEmpty) {
      return 'PAN number is required';
    }
    if (value.length != 10) {
      return 'PAN number must be 10 characters';
    }
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(value.toUpperCase())) {
      return 'PAN format: ABCDE1234F (5 letters + 4 digits + 1 letter)';
    }
    return null;
  }

  /// Validate GST number (15 characters: 2 digits + 10 characters + 3 digits)
  String? _validateGST(String? value) {
    if (value == null || value.isEmpty) {
      return null; // GST is optional
    }
    if (value.length != 15) {
      return 'GST number must be 15 characters';
    }
    if (!RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
    ).hasMatch(value.toUpperCase())) {
      return 'GST format: 22AAAAA0000A1Z5 (2 digits + 5 letters + 4 digits + 1 letter + 1 digit/letter + Z + 1 digit/letter)';
    }
    return null;
  }

  /// Validate IFSC code (11 characters: 4 letters + 7 digits)
  String? _validateIFSC(String? value) {
    if (value == null || value.isEmpty) {
      return 'IFSC code is required';
    }
    if (value.length != 11) {
      return 'IFSC code must be 11 characters';
    }
    if (!RegExp(r'^[A-Z]{4}[0-9]{7}$').hasMatch(value.toUpperCase())) {
      return 'IFSC format: ABCD0001234 (4 letters + 7 digits)';
    }
    return null;
  }

  /// Validate bank account number (9-18 digits)
  String? _validateBankAccount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Bank account number is required';
    }
    if (value.length < 9 || value.length > 18) {
      return 'Bank account number must be 9-18 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Bank account number must contain only digits';
    }
    return null;
  }

  /// Validate required fields
  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  bool _isValidUrl(String url, {List<String>? requiredPatterns}) {
    if (url.isEmpty) return true; // Optional fields
    try {
      final uri = Uri.parse(url);
      if (!uri.hasAbsolutePath) return false;
      if (requiredPatterns != null) {
        return requiredPatterns.any((pattern) => url.contains(pattern));
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _pickImage(Function(String) onPicked) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) onPicked(image.path);
  }

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
    // Only move to next page, do not submit to backend!
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

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

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1️⃣ Validate required images
      if (_logoFile == null) throw Exception('Please upload a studio logo');
      if (_aadharFrontPath == null || _aadharBackPath == null) {
        throw Exception('Please upload both Aadhaar front and back photos');
      }
      if (_studioPhotos.isEmpty || _studioPhotos.length < 5) {
        throw Exception('Please upload at least 5 studio photos');
      }

      // 2️⃣ Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final ownerId = widget.user.id ?? '';

      // ---------------------------
      // 🔹 Helpers for uploads
      // ---------------------------
      Future<String?> _uploadSingleImage(
        File file,
        String url,
        String fieldName,
      ) async {
        var request = http.MultipartRequest('POST', Uri.parse(url));
        final ext = file.path.split('.').last.toLowerCase();
        request.files.add(
          await http.MultipartFile.fromPath(
            fieldName,
            file.path,
            contentType: MediaType('image', (ext == 'png') ? 'png' : 'jpeg'),
          ),
        );

        var response = await request.send();
        print('Upload to $url status: ${response.statusCode}');
        final respStr = await response.stream.bytesToString();
        print('Upload response: $respStr');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(respStr);
          return data['path'] as String?;
        } else {
          throw Exception('Upload failed: $respStr');
        }
      }

      Future<List<String>> _uploadMultipleImages(
        List<File> files,
        String url,
        String fieldName,
      ) async {
        var request = http.MultipartRequest('POST', Uri.parse(url));

        for (var f in files) {
          final mimeType = lookupMimeType(f.path) ?? 'application/octet-stream';
          final parts = mimeType.split('/'); // ['image','jpeg']

          request.files.add(
            await http.MultipartFile.fromPath(
              fieldName,
              f.path,
              contentType: MediaType(parts[0], parts[1]),
            ),
          );
        }

        var response = await request.send();
        final respStr = await response.stream.bytesToString();
        print('Upload to $url status: ${response.statusCode}');
        print('Upload response: $respStr');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(respStr);
          return List<String>.from(data['paths']);
        } else {
          throw Exception('Studio images upload failed: $respStr');
        }
      }

      // ---------------------------
      // 🔹 Upload images one by one
      // ---------------------------

      // ✅ Upload logo
      final logoPath = await _uploadSingleImage(
        File(_logoFile!.path),
        "http://147.93.19.17:5002/api/studios/logo",
        "image",
      );
      if (logoPath == null) throw Exception("Logo upload failed!");

      // ✅ Aadhaar front
      final aadharFrontPath = await _uploadSingleImage(
        File(_aadharFrontPath!),
        "http://147.93.19.17:5002/api/studios/aadhar-front",
        "image",
      );
      if (aadharFrontPath == null)
        throw Exception("Aadhaar front upload failed!");

      // ✅ Aadhaar back
      final aadharBackPath = await _uploadSingleImage(
        File(_aadharBackPath!),
        "http://147.93.19.17:5002/api/studios/aadhar-back",
        "image",
      );
      if (aadharBackPath == null)
        throw Exception("Aadhaar back upload failed!");

      // ✅ Studio images
      final studioPhotoPaths = await _uploadMultipleImages(
        _studioPhotos.map((p) => File(p)).toList(),
        "http://147.93.19.17:5002/api/studios/images",
        "images",
      );
      if (studioPhotoPaths.length < 5)
        throw Exception("Studio images upload failed!");

      // ---------------------------
      // 🔹 Prepare registration data
      // ---------------------------
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

        // ✅ Uploaded image paths
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

      // ---------------------------
      // 🔹 Submit studio registration
      // ---------------------------
      final response = await http.post(
        Uri.parse('http://147.93.19.17:5002/api/studios'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(studioData),
      );

      print('Studio registration status: ${response.statusCode}');
      print('Studio registration response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Studio registered successfully!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StudioSuccessScreen(user: widget.user),
          ),
        );
      } else {
        throw Exception('Failed to register studio: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting form: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Page 1: Studio details
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ðŸ”µ Top Welcome Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: 60,
                        bottom: 40,
                        left: 24,
                        right: 24,
                      ), // added side padding
                      decoration: const BoxDecoration(
                        color: Color(0xFF3A5ED4), // Solid background color
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start, // left align text
                        children: [
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

                    // ðŸ”½ Your existing form content
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
                              // textCapitalization: TextCapitalization.words,
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
                                hintText: 'Enter link here',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  _validateRequired(v, 'Registered Address'),
                              //textCapitalization: TextCapitalization.sentences,
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
                              validator: (v) => _validateEmail(v),
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
                              validator: (v) => _validatePhoneNumber(v),
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
                              validator: (v) => _validateGST(v),
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
                              validator: (v) => _validatePAN(v),
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
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Aadhar Number of Owner',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _pickImage(
                                              (path) => setState(
                                                () => _aadharFrontPath = path,
                                              ),
                                            ),
                                            child: Container(
                                              height:
                                                  100, // Increased from 60 to 100
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.grey,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: _aadharFrontPath == null
                                                  ? Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: const [
                                                        Icon(
                                                          Icons.add_a_photo,
                                                          size: 30,
                                                          color: Colors.grey,
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          'Front',
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  : Image.file(
                                                      File(_aadharFrontPath!),
                                                      fit: BoxFit.cover,
                                                    ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _pickImage(
                                              (path) => setState(
                                                () => _aadharBackPath = path,
                                              ),
                                            ),
                                            child: Container(
                                              height:
                                                  100, // Increased from 60 to 100
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.grey,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: _aadharBackPath == null
                                                  ? Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: const [
                                                        Icon(
                                                          Icons.add_a_photo,
                                                          size: 30,
                                                          color: Colors.grey,
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          'Back',
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  : Image.file(
                                                      File(_aadharBackPath!),
                                                      fit: BoxFit.cover,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
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
                              validator: (v) => _validateBankAccount(v),
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
                              validator: (v) => _validateIFSC(v),
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
                                  : () => _registerStudioFirstPage(),
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

              // Page 2: Logo and photos
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ðŸ”µ Top Welcome Header with Back Arrow
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
                              const SizedBox(
                                height: 1,
                              ), // Slight space from top
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
                        // Back Arrow positioned top left
                        Positioned(
                          top:
                              -1, // match padding top + slight offset for center alignment with text
                          left: -1, // match left padding for visual match
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
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
                            children: [
                              const Text(
                                'Upload Logo',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                          GestureDetector(
                            onTap: () async {
                              final pickedFile = await _picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (pickedFile != null) {
                                setState(() {
                                  _logoFile = File(pickedFile.path);
                                });
                              }
                            },
                            child: Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _logoFile != null
                                  ? Image.file(_logoFile!, fit: BoxFit.cover)
                                  : const Center(
                                      child: Icon(Icons.add_a_photo),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'PNG / JPEG / JPG\nMax size: 2 MB',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
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
                          const SizedBox(height: 8),
                          const Text(
                            'Only PNG / JPEG / JPG\nMax size: 2 MB per photo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),

                          GridView.builder(
                            shrinkWrap: true,
                            itemCount: _studioPhotos.length < 6
                                ? _studioPhotos.length + 1
                                : 6,
                            physics: const NeverScrollableScrollPhysics(),
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
                                      child:
                                          photo.startsWith(
                                            "http",
                                          ) // already uploaded
                                          ? Image.network(
                                              photo,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              File(photo),
                                              fit: BoxFit.cover,
                                            ), // local preview
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _studioPhotos.removeAt(index);
                                          });
                                        },
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

                              // Add new photo button
                              return GestureDetector(
                                onTap: () => _pickImage((path) {
                                  setState(() {
                                    if (_studioPhotos.length < 6)
                                      _studioPhotos.add(path);
                                  });
                                }),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.add),
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
                              // textCapitalization: TextCapitalization.sentences,
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
                                if (v == null || v.trim().isEmpty)
                                  return null; // optional
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
                                if (v == null || v.trim().isEmpty)
                                  return null; // optional
                                if (!v.toLowerCase().contains('facebook')) {
                                  return 'Please enter a valid Facebook URL';
                                }
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
                                if (v == null || v.trim().isEmpty)
                                  return null; // optional
                                if (!v.toLowerCase().contains('youtube')) {
                                  return 'Please enter a valid YouTube URL';
                                }
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
                                if (v == null || v.trim().isEmpty)
                                  return null; // optional
                                if (!v.toLowerCase().contains('instagram')) {
                                  return 'Please enter a valid Instagram URL';
                                }
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
                                onChanged: (val) {
                                  setState(() => _termsAccepted = val ?? false);
                                },
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
                                          ..onTap = () async {
                                            const url =
                                                'https://dancekatta.com/terms-of-service/';
                                            if (!await launchUrlString(
                                              url,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            )) {
                                              debugPrint(
                                                'Could not launch $url',
                                              );
                                            }
                                          },
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
                                  : () => _submitForm(),

                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    (_termsAccepted && !_isSubmitting)
                                    ? const Color(0xFF2563EB) // Enabled color
                                    : Colors.grey.shade400, // Disabled color
                                foregroundColor:
                                    (_termsAccepted && !_isSubmitting)
                                    ? Colors.white
                                    : Colors.white70, // Slightly faded text
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
