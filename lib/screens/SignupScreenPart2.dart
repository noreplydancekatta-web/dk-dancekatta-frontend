//final updated
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session_manager.dart';
import '../models/user_model.dart';
import 'home_screen.dart';

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
  String? _skillsError;
  bool _isLoading = false;

  // ✅ Centralized base URL
  static const String _baseUrl = 'http://147.93.19.17:5001/api/signup';

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

  @override
  void dispose() {
    _youtubeController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  void _addSkillRow() {
    setState(() => skills.add({'style': null, 'level': null}));
  }

  Widget _buildSkillRow(int index) {
    final selectedStyles = skills
        .asMap()
        .entries
        .where((entry) => entry.key != index)
        .map((entry) => entry.value['style'])
        .toList();

    final availableStyles = danceStyles
        .where((style) => !selectedStyles.contains(style))
        .toList();

    final style = skills[index]['style'];
    final level = skills[index]['level'];
    String? styleError;
    String? levelError;

    if ((style == null || style.isEmpty) &&
        (level != null && level.isNotEmpty)) {
      styleError = 'Select dance style';
    }
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
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownMenu<String>(
                  initialSelection: skills[index]['style'] ?? '',
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
                  dropdownMenuEntries: availableStyles
                      .map((s) => DropdownMenuEntry<String>(value: s, label: s))
                      .toList(),
                  onSelected: (val) {
                    if (selectedStyles.contains(val)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You have already selected this style'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else {
                      setState(() => skills[index]['style'] = val);
                    }
                  },
                  menuStyle: MenuStyle(
                    alignment: AlignmentDirectional.bottomStart,
                    maximumSize: WidgetStateProperty.all(
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
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expertise Level',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownMenu<String>(
                  initialSelection: skills[index]['level'] ?? '',
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
                  dropdownMenuEntries: expertiseLevels
                      .map((l) => DropdownMenuEntry<String>(value: l, label: l))
                      .toList(),
                  onSelected: (val) =>
                      setState(() => skills[index]['level'] = val),
                  menuStyle: MenuStyle(
                    alignment: AlignmentDirectional.bottomStart,
                    maximumSize: WidgetStateProperty.all(
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

  /* ========================
     STEP 1 — SEND OTP
  ======================== */
  Future<void> _startOtpFlow() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email.toLowerCase().trim()}),
      );

      setState(() => _isLoading = false);
      if (!mounted) return;

      if (response.statusCode == 200) {
        _showOtpDialog();
      } else {
        final body = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? 'Failed to send OTP')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.')),
      );
    }
  }

  /* ========================
     STEP 2 — OTP DIALOG
  ======================== */
  Future<void> _showOtpDialog() async {
    final TextEditingController otpController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'An OTP has been sent to ${widget.email}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Enter 6-digit OTP',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final isVerified = await _verifyOtp(otpController.text.trim());
              if (isVerified && mounted) {
                Navigator.pop(dialogContext);
                _registerUser(); // ✅ only proceeds after OTP is confirmed
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  /* ========================
     STEP 3 — VERIFY OTP
  ======================== */
  Future<bool> _verifyOtp(String otp) async {
    if (otp.isEmpty || otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email.toLowerCase().trim(),
          'otp': otp,
        }),
      );

      if (!mounted) return false;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP Verified Successfully!')),
        );
        return true;
      } else {
        final body = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? 'Invalid OTP')),
        );
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error verifying OTP')),
      );
      return false;
    }
  }

  /* ========================
     STEP 4 — REGISTER USER
  ======================== */
  Future<void> _registerUser() async {
    setState(() => _isLoading = true);

    try {
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
        "youtubeLink": _youtubeController.text.trim(),
        "facebookLink": _facebookController.text.trim(),
        "instagramLink": _instagramController.text.trim(),
        "isProfessional": _isProfessional,
        // ✅ FIXED: key name matches what backend's User schema stores as 'experience'
        "experience": _isProfessional == "Yes"
            ? _experienceController.text.trim()
            : "",
        "skills": skills
            .where((s) => s['style'] != null && s['level'] != null)
            .map((s) => {"style": s['style'], "level": s['level']})
            .toList(),
        if (widget.profilePhoto != null) "profilePhoto": widget.profilePhoto,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/register-full'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      setState(() => _isLoading = false);
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        _showResultDialog(isSuccess: true, userData: responseData);
      } else {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['message'] ?? "Registration failed")),
        );
        _showResultDialog(isSuccess: false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      _showResultDialog(isSuccess: false);
    }
  }

  /* ========================
     RESULT DIALOG
  ======================== */
  Future<void> _showResultDialog({
    required bool isSuccess,
    Map<String, dynamic>? userData,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                isSuccess ? "Registration Successful" : "Failed to register",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isSuccess && userData != null
                    ? () async {
                        // ✅ userData['user'] is the nested user object from { message, user }
                        final user = UserModel.fromJson(userData['user']);
                        await SessionManager.saveUserSession(user.id ?? '');

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'A welcome email has been sent to your registered email!',
                            ),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 4),
                          ),
                        );

                        Navigator.pop(context); // close dialog
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HomeScreen(user: user),
                          ),
                          (route) => false,
                        );
                      }
                    : () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  isSuccess ? "Okay, Cool!" : "Try again",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ========================
     BUILD UI
  ======================== */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 20,
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
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome to',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
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
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Form Body ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
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
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _facebookController,
                        decoration: const InputDecoration(
                          labelText: 'Facebook Page Link',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _instagramController,
                        decoration: const InputDecoration(
                          labelText: 'Instagram Page Link',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _isProfessional,
                        decoration: const InputDecoration(
                          hintText: 'Are you a professional dancer?',
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
                      if (_isProfessional == 'Yes')
                        TextFormField(
                          controller: _experienceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            hintText: 'Enter experience in years',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              (_isProfessional == 'Yes' &&
                                  (value == null || value.isEmpty))
                              ? 'This field is required'
                              : null,
                        ),
                      const SizedBox(height: 24),

                      // ── Skills ───────────────────────────────────────
                      ...List.generate(skills.length, _buildSkillRow),
                      if (_skillsError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _skillsError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: _addSkillRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Skill'),
                      ),
                      const SizedBox(height: 30),

                      // ── Submit ───────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  bool hasError = false;
                                  _skillsError = null;

                                  if (skills.isEmpty ||
                                      !skills.any(
                                        (s) =>
                                            s['style'] != null &&
                                            s['level'] != null,
                                      )) {
                                    _skillsError =
                                        'Please add at least one skill with both style and level';
                                    hasError = true;
                                  }

                                  for (int i = 0; i < skills.length; i++) {
                                    final s = skills[i]['style'];
                                    final l = skills[i]['level'];
                                    if (((s == null || s.isEmpty) &&
                                            (l != null && l.isNotEmpty)) ||
                                        ((s != null && s.isNotEmpty) &&
                                            (l == null || l.isEmpty))) {
                                      _skillsError =
                                          'Please fill all skill rows correctly';
                                      hasError = true;
                                      break;
                                    }
                                  }

                                  setState(() {});

                                  if (_formKey.currentState!.validate() &&
                                      !hasError) {
                                    _startOtpFlow();
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
                            disabledBackgroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
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
