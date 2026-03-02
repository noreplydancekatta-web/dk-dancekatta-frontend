// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/upload_service.dart';
import '../constants.dart'; // for BASE_URL + getFullImageUrl

class FinishProfileScreen extends StatefulWidget {
  final UserModel user;

  const FinishProfileScreen({super.key, required this.user});

  @override
  State<FinishProfileScreen> createState() => _FinishProfileScreenState();
}

class CapitalizeWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1).toLowerCase()
              : '',
        )
        .join(' ');

    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _FinishProfileScreenState extends State<FinishProfileScreen> {
  // Controllers
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _altMobileController;
  late TextEditingController _dobController;
  late TextEditingController _guardianNameController;
  late TextEditingController _guardianMobileController;
  late TextEditingController _guardianEmailController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _pincodeController;
  late TextEditingController _youtubeController;
  late TextEditingController _facebookController;
  late TextEditingController _instagramController;
  late TextEditingController _experienceController;

  String? _isProfessional;
  String? _profilePhoto;
  List<Map<String, String?>> _skills = [];
  String? _selectedCity;
  String? _selectedState;
  String? _selectedCountry;

  String? _cityError;
  String? _stateError;
  String? _countryError;

  List<String> _cities = [];
  List<String> _states = [];
  List<String> _countries = [];
  List<String> _danceStyles = [];
  List<String> _levels = [];

  bool _loadingDropdowns = true;
  bool _isSubmitting = false;
  final _formKey = GlobalKey<FormState>();

  /// Check if user is 18 years or older
  bool get _isUserAdult {
    if (_dobController.text.isEmpty) return true;
    try {
      final birthDate = DateTime.parse(_dobController.text);
      final today = DateTime.now();
      final age = today.year - birthDate.year;
      final monthDiff = today.month - birthDate.month;
      final dayDiff = today.day - birthDate.day;

      if (monthDiff < 0 || (monthDiff == 0 && dayDiff < 0)) {
        return age - 1 >= 18;
      }
      return age >= 18;
    } catch (e) {
      return true;
    }
  }

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

  /// Validate pincode (6 digits)
  String? _validatePincode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Pincode is required';
    }
    if (value.length != 6) {
      return 'Pincode must be 6 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Pincode must contain only digits';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _firstNameController = TextEditingController(text: user.firstName);
    _lastNameController = TextEditingController(text: user.lastName);
    _emailController = TextEditingController(text: user.email);
    _mobileController = TextEditingController(text: user.mobile);
    _altMobileController = TextEditingController(text: user.altMobile);
    _dobController = TextEditingController(text: user.dateOfBirth);
    _guardianNameController = TextEditingController(text: user.guardianName);
    _guardianMobileController = TextEditingController(
      text: user.guardianMobile,
    );
    _guardianEmailController = TextEditingController(text: user.guardianEmail);
    _addressController = TextEditingController(text: user.address);
    _cityController = TextEditingController(text: user.city);
    _stateController = TextEditingController(text: user.state);
    _countryController = TextEditingController(text: user.country);
    _pincodeController = TextEditingController(text: user.pincode);
    _youtubeController = TextEditingController(text: user.youtube);
    _facebookController = TextEditingController(text: user.facebook);
    _instagramController = TextEditingController(text: user.instagram);
    _experienceController = TextEditingController(text: user.experience);
    _isProfessional = user.isProfessional;
    _profilePhoto = user.profilePhoto;
    _skills = (user.skills ?? [])
        .map<Map<String, String?>>((s) => {'style': s.style, 'level': s.level})
        .toList();

    _fetchDropdowns();
  }

  void _sanitizeSkills() {
    setState(() {
      _skills = _skills.where((s) {
        final style = s['style'];
        final level = s['level'];
        if (style == null || style.isEmpty) return false;
        if (level == null || level.isEmpty) return false;
        return true;
      }).toList();
    });
  }

  Future<void> _fetchAddressFromPincode(
    String pincode, {
    bool isUserAction = false,
  }) async {
    if (pincode.length != 6) return;

    try {
      final response = await http.get(
        Uri.parse('https://api.postalpincode.in/pincode/$pincode'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is List &&
            data.isNotEmpty &&
            data[0]['Status'] == 'Success' &&
            data[0]['PostOffice'] != null &&
            data[0]['PostOffice'].isNotEmpty) {
          final postOffice = data[0]['PostOffice'][0];

          final city = postOffice['Name'] ?? '';
          final state = postOffice['State'] ?? '';
          final country = postOffice['Country'] ?? 'India';

          setState(() {
            if (city.isNotEmpty && !_cities.contains(city)) _cities.add(city);
            if (state.isNotEmpty && !_states.contains(state))
              _states.add(state);
            if (country.isNotEmpty && !_countries.contains(country))
              _countries.add(country);

            _cityController.text = city;
            _stateController.text = state;
            _countryController.text = country;

            if (isUserAction) {
              _cityError = null;
              _stateError = null;
              _countryError = null;
            }
          });
        } else {
          if (isUserAction) {
            _showPincodeError('Invalid pincode');
          }
        }
      }
    } catch (e) {
      if (isUserAction) {
        _showPincodeError('Failed to fetch address');
      }
    }
  }

  void _showPincodeError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _fetchDropdowns() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('http://147.93.19.17:5002/api/cities')),
        http.get(Uri.parse('http://147.93.19.17:5002/api/states')),
        http.get(Uri.parse('http://147.93.19.17:5002/api/countries')),
        http.get(Uri.parse('http://147.93.19.17:5002/api/dance-styles')),
        http.get(Uri.parse('http://147.93.19.17:5002/api/levels')),
      ]);

      setState(() {
        _cities = [for (var e in jsonDecode(responses[0].body)) e['name']];
        _states = [for (var e in jsonDecode(responses[1].body)) e['name']];
        _countries = [for (var e in jsonDecode(responses[2].body)) e['name']];
        _danceStyles = [for (var e in jsonDecode(responses[3].body)) e['name']];
        _levels = [for (var e in jsonDecode(responses[4].body)) e['name']];
        _loadingDropdowns = false;

        if (_cityController.text.isNotEmpty &&
            !_cities.contains(_cityController.text)) {
          _cities.add(_cityController.text);
        }
        if (_stateController.text.isNotEmpty &&
            !_states.contains(_stateController.text)) {
          _states.add(_stateController.text);
        }
        if (_countryController.text.isNotEmpty &&
            !_countries.contains(_countryController.text)) {
          _countries.add(_countryController.text);
        }
      });

      if (_pincodeController.text.isNotEmpty &&
          _pincodeController.text.length == 6) {
        await _fetchAddressFromPincode(
          _pincodeController.text,
          isUserAction: false,
        );
      }
      _sanitizeSkills();
    } catch (e) {
      print('Error fetching dropdowns: $e');
      setState(() {
        _loadingDropdowns = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    try {
      setState(() => _isSubmitting = true);

      String relativePath = await UploadService.uploadImage(
        File(pickedFile.path),
        "api/users/profile-image",
      );

      setState(() {
        _profilePhoto = relativePath;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully')),
      );
    } catch (e) {
      debugPrint('Error uploading image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error uploading image')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dobController.text) ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobController.text = picked.toIso8601String().split("T")[0];
    }
  }

  Widget _spacedField(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: child);

  Widget _buildSkillField(int index) {
    final String? currentStyle = _skills[index]['style'];
    final String? currentLevel = _skills[index]['level'];

    final selectedStyles = _skills
        .asMap()
        .entries
        .where((entry) => entry.key != index)
        .map((entry) => entry.value['style'])
        .where((s) => s != null && s.isNotEmpty)
        .toList();

    final availableStyles = {
      ..._danceStyles,
      if (currentStyle != null && currentStyle.isNotEmpty) currentStyle,
    }.where((s) => !selectedStyles.contains(s) || s == currentStyle).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: DropdownMenu<String>(
              initialSelection:
                  (currentStyle != null &&
                      currentStyle.isNotEmpty &&
                      availableStyles.contains(currentStyle))
                  ? currentStyle
                  : null,
              expandedInsets: EdgeInsets.zero,
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                isDense: true,
              ),
              label: const Text('Dance Style'),
              hintText: 'Select Style',
              dropdownMenuEntries: availableStyles
                  .map((s) => DropdownMenuEntry<String>(value: s, label: s))
                  .toList(),
              onSelected: (val) =>
                  setState(() => _skills[index]['style'] = val ?? ''),
              menuStyle: MenuStyle(
                alignment: AlignmentDirectional.bottomStart,
                maximumSize: MaterialStateProperty.all<Size>(
                  const Size.fromHeight(200),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: DropdownMenu<String>(
              initialSelection:
                  (currentLevel != null &&
                      currentLevel.isNotEmpty &&
                      _levels.contains(currentLevel))
                  ? currentLevel
                  : null,
              expandedInsets: EdgeInsets.zero,
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                isDense: true,
              ),
              label: const Text('Level'),
              hintText: 'Select Level',
              dropdownMenuEntries: _levels
                  .map((l) => DropdownMenuEntry<String>(value: l, label: l))
                  .toList(),
              onSelected: (val) =>
                  setState(() => _skills[index]['level'] = val ?? ''),
              menuStyle: MenuStyle(
                alignment: AlignmentDirectional.bottomStart,
                maximumSize: MaterialStateProperty.all<Size>(
                  const Size.fromHeight(200),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _skills.removeAt(index)),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Future<void> _submitProfile() async {
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

    // ✅ Validate profile photo
    if (_profilePhoto == null || _profilePhoto!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ Validate professional choreographer selection
    if (_isProfessional == null || _isProfessional!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select if you are a professional choreographer',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ Validate experience if professional
    if (_isProfessional == 'Yes' && (_experienceController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Teaching experience is required for professional choreographers',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Skill validation
    for (int i = 0; i < _skills.length; i++) {
      final style = _skills[i]['style'];
      final level = _skills[i]['level'];

      if (style != null && style.isNotEmpty) {
        if (level == null || level.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please select an expertise level for "$style"'),
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() => _isSubmitting = false);
          return;
        }
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final updatedData = {
        "firstName": _firstNameController.text,
        "lastName": _lastNameController.text,
        "email": _emailController.text,
        "mobile": _mobileController.text,
        "altMobile": _altMobileController.text,
        "dateOfBirth": _dobController.text,
        "guardianName": _isUserAdult ? "" : _guardianNameController.text,
        "guardianMobile": _isUserAdult ? "" : _guardianMobileController.text,
        "guardianEmail": _isUserAdult ? "" : _guardianEmailController.text,
        "address": _addressController.text,
        "city": _cityController.text,
        "state": _stateController.text,
        "country": _countryController.text,
        "pincode": _pincodeController.text,
        "youtube": _youtubeController.text,
        "facebook": _facebookController.text,
        "instagram": _instagramController.text,
        "isProfessional": _isProfessional,
        "experience": _experienceController.text,
        "skills": _skills,
      };

      if (_profilePhoto != null && _profilePhoto!.isNotEmpty) {
        if (_profilePhoto!.startsWith('/uploads/')) {
          updatedData["profilePhoto"] = _profilePhoto;
        } else if (_profilePhoto!.startsWith('http')) {
          updatedData["profilePhoto"] = Uri.parse(_profilePhoto!).path;
        }
      }

      if (widget.user.id == null || widget.user.id!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid user ID. Please try logging in again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final existingUser = await UserService.fetchUserById(widget.user.id!);
      if (existingUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not found. Please try logging in again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final updatedUser = await UserService.updateUserProfile(
        widget.user.id!,
        updatedData,
      );

      if (updatedUser != null) {
        final isComplete = updatedUser.isProfileFullyComplete;
        Navigator.pop(context, updatedUser);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isComplete
                  ? 'Profile completed successfully'
                  : 'Profile updated successfully! Please fill all required fields to complete your profile.',
            ),
            backgroundColor: isComplete ? Colors.green : Colors.blue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error submitting profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ✅ Required label with red * mark
  Widget _requiredLabel(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        appBar: AppBar(title: const Text("Finish Profile")),
        body:
            (_loadingDropdowns ||
                _cities.isEmpty ||
                _states.isEmpty ||
                _countries.isEmpty ||
                _danceStyles.isEmpty ||
                _levels.isEmpty)
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // ✅ Profile photo with red * indicator
                      GestureDetector(
                        onTap: _pickImage,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.grey[200],
                              backgroundImage:
                                  (_profilePhoto != null &&
                                      _profilePhoto!.isNotEmpty &&
                                      !_isSubmitting)
                                  ? NetworkImage(getFullImageUrl(_profilePhoto))
                                  : null,
                              child: _isSubmitting
                                  ? const CircularProgressIndicator(
                                      color: Colors.blue,
                                    )
                                  : (_profilePhoto == null ||
                                            _profilePhoto!.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 55,
                                            color: Colors.grey,
                                          )
                                        : null),
                            ),
                            const SizedBox(height: 6),
                            RichText(
                              text: const TextSpan(
                                text: 'Profile Photo',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                                children: [
                                  TextSpan(
                                    text: ' *',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ✅ First Name *
                      _spacedField(
                        TextFormField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            label: _requiredLabel('First Name'),
                          ),
                          validator: (value) => value?.isEmpty == true
                              ? 'First name is required'
                              : null,
                        ),
                      ),

                      // ✅ Last Name *
                      _spacedField(
                        TextFormField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            label: _requiredLabel('Last Name'),
                          ),
                          validator: (value) => value?.isEmpty == true
                              ? 'Last name is required'
                              : null,
                        ),
                      ),

                      // ✅ Email *
                      _spacedField(
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            label: _requiredLabel('Email'),
                          ),
                          validator: (value) {
                            if (value?.isEmpty == true)
                              return 'Email is required';
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value!)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                      ),

                      // ✅ Mobile *
                      _spacedField(
                        TextFormField(
                          controller: _mobileController,
                          decoration: InputDecoration(
                            label: _requiredLabel('Mobile'),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: _validatePhoneNumber,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 10,
                        ),
                      ),

                      // Alt Mobile (optional)
                      _spacedField(
                        TextFormField(
                          controller: _altMobileController,
                          decoration: const InputDecoration(
                            labelText: 'Alt Mobile (Optional)',
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value?.isNotEmpty == true) {
                              return _validatePhoneNumber(value);
                            }
                            return null;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 10,
                        ),
                      ),

                      // ✅ Date of Birth *
                      _spacedField(
                        TextFormField(
                          controller: _dobController,
                          readOnly: true,
                          decoration: InputDecoration(
                            label: _requiredLabel('Date of Birth'),
                          ),
                          onTap: _pickDate,
                          validator: (value) => value?.isEmpty == true
                              ? 'Date of birth is required'
                              : null,
                        ),
                      ),

                      // Guardian fields (only for under 18)
                      if (!_isUserAdult) ...[
                        _spacedField(
                          TextFormField(
                            controller: _guardianNameController,
                            textCapitalization: TextCapitalization.words,
                            inputFormatters: [CapitalizeWordsFormatter()],
                            decoration: InputDecoration(
                              label: _requiredLabel('Guardian Name'),
                            ),
                            validator: (value) => value?.isEmpty == true
                                ? 'Guardian name is required'
                                : null,
                          ),
                        ),
                        _spacedField(
                          TextFormField(
                            controller: _guardianMobileController,
                            decoration: const InputDecoration(
                              labelText: 'Guardian Mobile',
                            ),
                            keyboardType: TextInputType.phone,
                            validator: _validatePhoneNumber,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            maxLength: 10,
                          ),
                        ),
                        _spacedField(
                          TextFormField(
                            controller: _guardianEmailController,
                            decoration: const InputDecoration(
                              labelText: 'Guardian Email',
                            ),
                            validator: (value) {
                              if (value?.isEmpty == true)
                                return 'Guardian email is required';
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value!)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],

                      // ✅ Address (Flat No) *
                      _spacedField(
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            label: _requiredLabel('Flat No / Address'),
                          ),
                          validator: (value) => value?.isEmpty == true
                              ? 'Address is required'
                              : null,
                        ),
                      ),

                      // ✅ Pincode *
                      _spacedField(
                        TextFormField(
                          controller: _pincodeController,
                          decoration: InputDecoration(
                            label: _requiredLabel('Pincode'),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _validatePincode,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 6,
                          onChanged: (value) {
                            if (value.length == 6) {
                              _fetchAddressFromPincode(
                                value,
                                isUserAction: true,
                              );
                            }
                          },
                        ),
                      ),

                      // ✅ City *
                      if (_cities.isNotEmpty)
                        _spacedField(
                          DropdownMenu<String>(
                            initialSelection:
                                (_cityController.text.isNotEmpty &&
                                    _cities.contains(_cityController.text))
                                ? _cityController.text
                                : null,
                            expandedInsets: EdgeInsets.zero,
                            inputDecorationTheme: InputDecorationTheme(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                            ),
                            label: _requiredLabel('City'),
                            hintText: 'Select City',
                            dropdownMenuEntries: _cities
                                .map(
                                  (city) => DropdownMenuEntry<String>(
                                    value: city,
                                    label: city,
                                  ),
                                )
                                .toList(),
                            onSelected: (val) => setState(
                              () => _cityController.text = val ?? '',
                            ),
                            menuStyle: MenuStyle(
                              alignment: AlignmentDirectional.bottomStart,
                              maximumSize: MaterialStateProperty.all<Size>(
                                const Size.fromHeight(200),
                              ),
                            ),
                          ),
                        ),

                      // ✅ State *
                      if (_states.isNotEmpty)
                        _spacedField(
                          DropdownMenu<String>(
                            initialSelection:
                                (_stateController.text.isNotEmpty &&
                                    _states.contains(_stateController.text))
                                ? _stateController.text
                                : null,
                            expandedInsets: EdgeInsets.zero,
                            inputDecorationTheme: InputDecorationTheme(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                            ),
                            label: _requiredLabel('State'),
                            hintText: 'Select State',
                            dropdownMenuEntries: _states
                                .map(
                                  (state) => DropdownMenuEntry<String>(
                                    value: state,
                                    label: state,
                                  ),
                                )
                                .toList(),
                            onSelected: (val) => setState(
                              () => _stateController.text = val ?? '',
                            ),
                            menuStyle: MenuStyle(
                              alignment: AlignmentDirectional.bottomStart,
                              maximumSize: MaterialStateProperty.all<Size>(
                                const Size.fromHeight(200),
                              ),
                            ),
                          ),
                        ),

                      // ✅ Country *
                      if (_countries.isNotEmpty)
                        _spacedField(
                          DropdownMenu<String>(
                            initialSelection:
                                (_countryController.text.isNotEmpty &&
                                    _countries.contains(
                                      _countryController.text,
                                    ))
                                ? _countryController.text
                                : null,
                            expandedInsets: EdgeInsets.zero,
                            inputDecorationTheme: InputDecorationTheme(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                            ),
                            label: _requiredLabel('Country'),
                            hintText: 'Select Country',
                            dropdownMenuEntries: _countries
                                .map(
                                  (country) => DropdownMenuEntry<String>(
                                    value: country,
                                    label: country,
                                  ),
                                )
                                .toList(),
                            onSelected: (val) => setState(
                              () => _countryController.text = val ?? '',
                            ),
                            menuStyle: MenuStyle(
                              alignment: AlignmentDirectional.bottomStart,
                              maximumSize: MaterialStateProperty.all<Size>(
                                const Size.fromHeight(200),
                              ),
                            ),
                          ),
                        ),

                      // Social links (optional)
                      _spacedField(
                        TextFormField(
                          controller: _youtubeController,
                          decoration: const InputDecoration(
                            labelText: 'YouTube',
                          ),
                        ),
                      ),
                      _spacedField(
                        TextFormField(
                          controller: _facebookController,
                          decoration: const InputDecoration(
                            labelText: 'Facebook',
                          ),
                        ),
                      ),
                      _spacedField(
                        TextFormField(
                          controller: _instagramController,
                          decoration: const InputDecoration(
                            labelText: 'Instagram',
                          ),
                        ),
                      ),

                      // ✅ Professional Choreographer *
                      _spacedField(
                        DropdownButtonFormField<String>(
                          value:
                              (_isProfessional == 'Yes' ||
                                  _isProfessional == 'No')
                              ? _isProfessional
                              : null,
                          items: const [
                            DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                            DropdownMenuItem(value: 'No', child: Text('No')),
                          ],
                          onChanged: (val) =>
                              setState(() => _isProfessional = val),
                          decoration: InputDecoration(
                            label: _requiredLabel(
                              'Are you a professional choreographer?',
                            ),
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Please select an option'
                              : null,
                        ),
                      ),

                      // ✅ Experience * (only shown and required when Professional = Yes)
                      if (_isProfessional == 'Yes')
                        _spacedField(
                          TextFormField(
                            controller: _experienceController,
                            decoration: InputDecoration(
                              label: _requiredLabel(
                                'Teaching Experience (in years)',
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? 'Experience is required'
                                : null,
                          ),
                        ),

                      // Dance Skills
                      if (!_loadingDropdowns) ...[
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Dance Skills',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._skills.asMap().entries.map(
                          (e) => _buildSkillField(e.key),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _skills.add({'style': null, 'level': null});
                              });
                            },
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
                                SizedBox(width: 6),
                                Icon(
                                  Icons.add_circle,
                                  color: Color(0xFF3A5ED4),
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitProfile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
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
                                  "Save Profile",
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
              ),
      );
    } catch (e) {
      print('Error building FinishProfileScreen: $e');
      return Scaffold(
        appBar: AppBar(title: const Text("Finish Profile")),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Something went wrong', style: TextStyle(fontSize: 18)),
              SizedBox(height: 8),
              Text('Please try again'),
            ],
          ),
        ),
      );
    }
  }
}
