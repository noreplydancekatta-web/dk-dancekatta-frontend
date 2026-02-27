import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/upload_service.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
// import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import '../models/user_model.dart';
import '../screens/signup_screen.dart';
import '../services/session_manager.dart';

class SignupScreenPart2 extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String mobile;
  final String altMobile;
  final String dateOfBirth;
  final String guardianName;
  final String guardianMobile;
  final String guardianEmail;
  final String address;
  final String city;
  final String state;
  final String country;
  final String pincode;
  final String? profilePhoto;

  const SignupScreenPart2({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.mobile,
    required this.altMobile,
    required this.dateOfBirth,
    required this.guardianName,
    required this.guardianMobile,
    required this.guardianEmail,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.pincode,
    this.profilePhoto,
  });

  @override
  State<SignupScreenPart2> createState() => _SignupScreenPart2State();
}

class _SignupScreenPart2State extends State<SignupScreenPart2> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();

  String? _isProfessional;
  List<Map<String, String?>> skills = [];

  bool _isLoading = false;
  // State variables for image picking
  // File? _profileImage;
  // final ImagePicker _picker = ImagePicker();

  final List<String> danceStyles = [
    'Hip-Hop',
    'K-Pop',
    'Bharatanatyam',
    'Jazz',
    'Lavani',
    'Kathak',
    'Salsa',
    'Ballet',
    'Zumba',
    'Bollywood',
  ];

  final List<String> expertiseLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  String? _skillsError;

  void _addSkillRow() {
    setState(() {
      skills.add({'style': null, 'level': null});
    });
  }

  Widget _buildSkillRow(int index) {
    // Get all selected styles except the current row
    final selectedStyles = skills
        .asMap()
        .entries
        .where((entry) => entry.key != index)
        .map((entry) => entry.value['style'])
        .toList();

    // Filter danceStyles to remove already selected ones
    final availableStyles = danceStyles
        .where((style) => !selectedStyles.contains(style))
        .toList();

    final style = skills[index]['style'];
    final level = skills[index]['level'];
    String? styleError;
    String? levelError;

    // Validation: if level is filled but style is empty
    if ((style == null || style.isEmpty) &&
        (level != null && level.isNotEmpty)) {
      styleError = 'Select dance style';
    }
    // Validation: if style is filled but level is empty
    if ((style != null && style.isNotEmpty) &&
        (level == null || level.isEmpty)) {
      levelError = 'Select expertise level';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dance Style',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownMenu<String>(
                  initialSelection:
                      skills[index]['style'] ?? '', // Added null check
                  expandedInsets: EdgeInsets.zero,
                  inputDecorationTheme: InputDecorationTheme(
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  ),
                  hintText: 'Select Dance Style',
                  dropdownMenuEntries: availableStyles.map((style) {
                    return DropdownMenuEntry<String>(
                      value: style,
                      label: style,
                    );
                  }).toList(),
                  onSelected: (val) {
                    if (selectedStyles.contains(val)) {
                      // Extra safety validation
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('You have already selected this style'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else {
                      setState(() {
                        skills[index]['style'] = val;
                      });
                    }
                  },
                  menuStyle: MenuStyle(
                    alignment: AlignmentDirectional.bottomStart,
                    maximumSize: MaterialStateProperty.all<Size>(
                      const Size.fromHeight(200),
                    ),
                  ),
                ),
                if (styleError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      styleError,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Expertise Level dropdown
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expertise Level',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownMenu<String>(
                  initialSelection:
                      skills[index]['level'] ?? '', // Added null check
                  expandedInsets: EdgeInsets.zero,
                  inputDecorationTheme: InputDecorationTheme(
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  ),
                  hintText: 'Select Expertise Level',
                  dropdownMenuEntries: expertiseLevels.map((level) {
                    return DropdownMenuEntry<String>(
                      value: level,
                      label: level,
                    );
                  }).toList(),
                  onSelected: (val) {
                    setState(() {
                      skills[index]['level'] = val;
                    });
                  },
                  menuStyle: MenuStyle(
                    alignment:
                        AlignmentDirectional.bottomStart, // ✅ always downward
                    maximumSize: MaterialStateProperty.all<Size>(
                      const Size.fromHeight(200),
                    ),
                  ),
                ),
                if (levelError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      levelError,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Delete button
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8.0),
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => setState(() => skills.removeAt(index)),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> getUserIdFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  // Function to pick image from gallery
  // Future<void> _pickProfileImage() async {
  //   final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
  //   if (pickedFile != null) {
  //     setState(() {
  //       _profileImage = File(pickedFile.path);
  //     });
  //   }
  // }Uri.parse("http://192.168.0.101:5002/api/users");

  Future<void> _registerUser() async {
    setState(() => _isLoading = true);
    try {
      print('Profile photo being sent: ${widget.profilePhoto}'); // Debug print

      // Build payload only with non-empty profilePhoto
      final payload = {
        "firstName": widget.firstName,
        "lastName": widget.lastName,
        "email": widget.email.toLowerCase().trim(),
        "mobile": widget.mobile,
        "altMobile": widget.altMobile,
        "dateOfBirth": widget.dateOfBirth,
        "guardianName": widget.guardianName,
        "guardianMobile": widget.guardianMobile,
        "guardianEmail": widget.guardianEmail,
        "address": widget.address,
        "city": widget.city,
        "state": widget.state,
        "country": widget.country,
        "pincode": widget.pincode,

        // ✅ NEW FIELDS
        "youtubeLink": _youtubeController.text.trim(),
        "facebookLink": _facebookController.text.trim(),
        "instagramLink": _instagramController.text.trim(),
        "isProfessional": _isProfessional,
        "experienceYears": _isProfessional == "Yes"
            ? _experienceController.text.trim()
            : null,

        // ✅ Convert skills to clean array
        "skills": skills
            .where(
              (s) =>
                  s['style'] != null &&
                  s['style']!.isNotEmpty &&
                  s['level'] != null &&
                  s['level']!.isNotEmpty,
            )
            .map((s) => {"style": s['style'], "level": s['level']})
            .toList(),
      };

      if (widget.profilePhoto != null && widget.profilePhoto!.isNotEmpty) {
        // ✅ Only pass the relative path, do NOT convert to full URL
        payload["profilePhoto"] = widget.profilePhoto!;
      }

      final response = await http.post(
        Uri.parse("http://147.93.19.17:5002/api/users"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> userData = jsonDecode(response.body);
        setState(() => _isLoading = false);
        // 🚨 Check if the user is disabled
        if ((userData['status'] ?? '').toString().toLowerCase() == "disabled") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "This account has been disabled by the admin. Please try another email or contact support.",
              ),
              backgroundColor: Colors.red,
            ),
          );
          return; // ⛔ Stop here, don’t show success dialog or navigate
        }

        // ✅ No need to update profilePhoto again

        _showResultDialog(isSuccess: true, userData: userData);
      } else {
        final err = jsonDecode(response.body);
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['message'] ?? "Registration failed")),
        );

        _showResultDialog(isSuccess: false);
      }
    } catch (e) {
      _showResultDialog(isSuccess: false);
    }
  }

  Future<bool> _showResultDialog({
    required bool isSuccess,
    Map<String, dynamic>? userData,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.cancel,
                      size: 50,
                      color: isSuccess ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSuccess ? "Yayy!" : "Oh snap!",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSuccess
                          ? "Registration Successful"
                          : "Failed to register",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isSuccess && userData != null
                          ? () async {
                              final user = UserModel.fromJson(userData['user']);

                              // ✅ Save persistent login
                              await SessionManager.saveUserSession(
                                user.id ?? '',
                              );

                              // Close dialog
                              Navigator.pop(context, isSuccess);

                              // Navigate to Home
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HomeScreen(user: user),
                                ),
                                (route) => false,
                              );
                            }
                          : () {
                              // just close dialog if failed
                              Navigator.pop(context, isSuccess);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(isSuccess ? "Okay, Cool!" : "Try again"),
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode:
                AutovalidateMode.onUserInteraction, // Enable inline validation
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 20,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF3A5ED4), // Solid background color
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // 🔙 Back Arrow (top-left)
                      Positioned(
                        left: -18,
                        top: -18,
                        child: IconButton(
                          padding: EdgeInsets.zero, // ✅ remove default padding
                          constraints:
                              const BoxConstraints(), // ✅ remove default constraints
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 20, // you can tweak size here too
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),

                      // 🔵 Main content (pushed down so it doesn’t overlap arrow)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 20,
                        ), // space below arrow
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Portfolio & Work Experience Details",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _youtubeController,
                        decoration: const InputDecoration(
                          labelText: 'YouTube Page Link',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final pattern =
                                r'^(https?:\/\/)?(www\.)?youtube\.com\/.*$';
                            if (!RegExp(pattern).hasMatch(value.trim())) {
                              return 'Enter a valid YouTube link';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _facebookController,
                        decoration: const InputDecoration(
                          labelText: 'Facebook Page Link',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final pattern =
                                r'^(https?:\/\/)?(www\.)?facebook\.com\/.*$';
                            if (!RegExp(pattern).hasMatch(value.trim())) {
                              return 'Enter a valid Facebook link';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _instagramController,
                        decoration: const InputDecoration(
                          labelText: 'Instagram Page Link',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final pattern =
                                r'^(https?:\/\/)?(www\.)?instagram\.com\/.*$';
                            if (!RegExp(pattern).hasMatch(value.trim())) {
                              return 'Enter a valid Instagram link';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Are you a professional Choreographer?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _isProfessional,
                        decoration: const InputDecoration(
                          hintText: 'Select your answer',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                          DropdownMenuItem(value: 'No', child: Text('No')),
                        ],
                        onChanged: (value) =>
                            setState(() => _isProfessional = value),
                        validator: (value) =>
                            value == null ? 'Please select an option' : null,
                      ),
                      const SizedBox(height: 16),

                      // Teaching Experience (only if Yes)
                      if (_isProfessional == 'Yes')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Teaching Experience in Years',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' *',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _experienceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ], // ✅ Only numbers allowed],
                              decoration: const InputDecoration(
                                hintText: 'Enter experience in years',
                                border: OutlineInputBorder(),
                              ),
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (value) {
                                if (_isProfessional == 'Yes') {
                                  if (value == null || value.isEmpty) {
                                    return 'This field is required';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),

                      // Section Label
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Skills',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Skill rows with dropdowns
                      ...List.generate(skills.length, _buildSkillRow),
                      if (_skillsError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, left: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _skillsError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),

                      // Add Skill Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _addSkillRow,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Add Skill',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(
                                width: 6,
                              ), // spacing between text and icon
                              Icon(
                                Icons.add_circle,
                                color: Color(0xFF3A5ED4),
                                size: 26, // 🔥 increased size
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            bool hasError = false;
                            _skillsError = null;

                            // Validate skills: at least one skill with both style and level
                            if (skills.isEmpty ||
                                !skills.any(
                                  (s) =>
                                      (s['style'] != null &&
                                          s['style']!.isNotEmpty) &&
                                      (s['level'] != null &&
                                          s['level']!.isNotEmpty),
                                )) {
                              _skillsError =
                                  'Please add at least one skill with both style and level';
                              hasError = true;
                            }

                            // Validate each skill row for style/level dependency
                            for (int i = 0; i < skills.length; i++) {
                              final style = skills[i]['style'];
                              final level = skills[i]['level'];
                              if ((style == null || style.isEmpty) &&
                                  (level != null && level.isNotEmpty)) {
                                _skillsError =
                                    'Please select dance style for all filled levels';
                                hasError = true;
                                break;
                              }
                              if ((style != null && style.isNotEmpty) &&
                                  (level == null || level.isEmpty)) {
                                _skillsError =
                                    'Please select expertise level for all filled styles';
                                hasError = true;
                                break;
                              }
                            }

                            setState(() {});

                            if (_formKey.currentState!.validate() &&
                                !hasError) {
                              _registerUser();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please fill all required fields correctly.',
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3A5ED4),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Register',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
