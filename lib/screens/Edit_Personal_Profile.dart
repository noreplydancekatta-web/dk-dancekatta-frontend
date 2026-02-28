import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/upload_service.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
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

class _EditProfileScreenState extends State<EditProfileScreen> {
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

  List<String> _cities = [];
  List<String> _states = [];
  List<String> _countries = [];
  List<String> _danceStyles = [];
  List<String> _levels = [];

  bool _hasUserChangedPincode = false;
  bool _loadingDropdowns = true;
  bool _isSubmitting = false;
  final _formKey = GlobalKey<FormState>();

  /// Check if user is 18 years or older
  bool get _isUserAdult {
    if (_dobController.text.isEmpty) return true; // Default to adult if no DOB
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
      return true; // Default to adult if date parsing fails
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _altMobileController.dispose();
    _dobController.dispose();
    _guardianNameController.dispose();
    _guardianMobileController.dispose();
    _guardianEmailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _pincodeController.dispose();
    _youtubeController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  void _sanitizeSkills() {
    setState(() {
      _skills = _skills.where((s) {
        final style = s['style'];
        final level = s['level'];

        if (style == null || style.isEmpty) return false;
        if (level == null || level.isEmpty) return false;

        return true; // ✅ do NOT depend on dropdown data
      }).toList();
    });
  }

  //fetch the data based on pincode
  Future<void> _fetchAddressFromPincode(String pincode) async {
    if (pincode.length != 6) return;

    try {
      final response = await http.get(
        Uri.parse('https://api.postalpincode.in/pincode/$pincode'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data != null &&
            data is List &&
            data.isNotEmpty &&
            data[0]['Status'] == 'Success' &&
            data[0]['PostOffice'] != null &&
            data[0]['PostOffice'].isNotEmpty) {
          final postOffice = data[0]['PostOffice'][0];

          // ✅ Use Name instead of District
          final city = postOffice['Name'] ?? '';
          final state = postOffice['State'] ?? '';
          final country = postOffice['Country'] ?? 'India';

          setState(() {
            if (!_cities.contains(city) && city.isNotEmpty) {
              _cities.insert(0, city);
            }
            if (!_states.contains(state) && state.isNotEmpty) {
              _states.insert(0, state);
            }
            if (!_countries.contains(country) && country.isNotEmpty) {
              _countries.insert(0, country);
            }

            _cityController.text = city;
            _stateController.text = state;
            _countryController.text = country;
          });
        } else {
          _showPincodeError('Invalid or not found pincode');
        }
      } else {
        _showPincodeError('Error fetching pincode: ${response.statusCode}');
      }
    } catch (e) {
      _showPincodeError('Failed to fetch address: $e');
    }
  }

  void _showPincodeError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _syncSavedAddressWithDropdowns() {
    setState(() {
      if (_cityController.text.isNotEmpty &&
          !_cities.contains(_cityController.text)) {
        _cities.insert(0, _cityController.text);
      }

      if (_stateController.text.isNotEmpty &&
          !_states.contains(_stateController.text)) {
        _states.insert(0, _stateController.text);
      }

      if (_countryController.text.isNotEmpty &&
          !_countries.contains(_countryController.text)) {
        _countries.insert(0, _countryController.text);
      }
    });
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

        print(
          'Dropdowns loaded - Cities: ${_cities.length}, States: ${_states.length}, Countries: ${_countries.length}, Dance Styles: ${_danceStyles.length}, Levels: ${_levels.length}',
        );
      });
      _syncSavedAddressWithDropdowns();
      _sanitizeSkills();
    } catch (e) {
      print('Error fetching dropdowns: $e');
      setState(() {
        _loadingDropdowns = false;
      });
    }
  }

  // Helper to build full URL for uploaded images
  String getFullImageUrl(String? filePath) {
    if (filePath == null || filePath.isEmpty) return '';
    // If backend returns path like "/uploads/filename.jpg", prepend host
    if (filePath.startsWith('/uploads/')) {
      return 'http://147.93.19.17:5002$filePath';
    }
    return filePath; // fallback if already full URL
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile == null) return;

      setState(() => _isSubmitting = true);

      // Use centralized UploadService
      String relativePath = await UploadService.uploadImage(
        File(pickedFile.path),
        "api/users/profile-image", // ✅ use correct endpoint
      );

      setState(() {
        _profilePhoto = relativePath; // store only relative path
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image uploaded successfully')),
      );
    } catch (e) {
      debugPrint('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error uploading profile image')),
      );
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

    // Get all styles selected in other rows to prevent duplicates
    final selectedStyles = _skills
        .asMap()
        .entries
        .where((entry) => entry.key != index)
        .map((entry) => entry.value['style'])
        .where((s) => s != null && s.isNotEmpty)
        .toList();

    // Filter available styles
    final availableStyles = {
      ..._danceStyles,
      if (currentStyle != null && currentStyle.isNotEmpty) currentStyle,
    }.where((s) => !selectedStyles.contains(s) || s == currentStyle).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dance Style Dropdown
          Expanded(
            flex: 4,
            child: DropdownMenu<String>(
              initialSelection:
                  (currentStyle != null &&
                      currentStyle.isNotEmpty &&
                      _danceStyles.contains(currentStyle))
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
                maximumSize: MaterialStateProperty.all(
                  const Size.fromHeight(200),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Level Dropdown
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

          // Delete Button
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

  Future<void> _showUpdateConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Profile?'),
        content: const Text(
          'Are you sure you want to update your profile information?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _updateProfile();
    }
  }

  Future<void> _updateProfile() async {
    if (_isSubmitting) return;

    // 1️⃣ Validate form
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2️⃣ Skill validation: level required if style is selected
    for (int i = 0; i < _skills.length; i++) {
      final style = _skills[i]['style'];
      final level = _skills[i]['level'];

      if (style != null && style.isNotEmpty) {
        if (level == null || level.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please select an expertise level for "${style}"'),
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() => _isSubmitting = false);
          return;
        }
      }
    }
    // 3️⃣ Proceed with your existing update logic
    setState(() => _isSubmitting = true);
    try {
      final userId = widget.user.id;
      if (userId == null || userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User ID missing. Cannot update profile'),
          ),
        );
        return;
      }

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
        // ✅ Always send only the relative path
        "profilePhoto":
            (_profilePhoto != null && _profilePhoto!.startsWith('/uploads/'))
            ? _profilePhoto
            : (_profilePhoto != null && _profilePhoto!.startsWith('http'))
            ? Uri.parse(_profilePhoto!).path
            : _profilePhoto,
        "skills": _skills,
      };

      // Use the user service to update the profile
      final updatedUser = await UserService.updateUserProfile(
        userId,
        updatedData,
      );

      if (updatedUser != null) {
        Navigator.pop(context, updatedUser); // <-- return updated user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile. Please try again.'),
          ),
        );
      }
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        appBar: AppBar(title: const Text("Edit Profile")),
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
                      // In your build method
                      GestureDetector(
                        onTap: () async {
                          // Pick image using ImagePicker
                          final pickedFile = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                          );
                          if (pickedFile == null) return;

                          setState(() {
                            _isSubmitting =
                                true; // Show loading indicator while uploading
                          });

                          try {
                            // Upload image using the helper
                            String
                            relativePath = await UploadService.uploadImage(
                              File(pickedFile.path),
                              "api/users/profile-image", // ✅ use correct endpoint
                            );

                            // Save only relative path (e.g. /uploads/profile/abc.jpg)
                            setState(() {
                              _profilePhoto = relativePath;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Profile image uploaded successfully!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            print("Image upload error: $e");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to upload image. Try again.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            setState(() {
                              _isSubmitting = false;
                            });
                          }
                        },
                        child: CircleAvatar(
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
                              : (_profilePhoto == null || _profilePhoto!.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 55,
                                        color: Colors.grey,
                                      )
                                    : null),
                        ),
                      ),

                      const SizedBox(height: 20),
                      _spacedField(
                        TextFormField(
                          controller: _firstNameController,
                          textCapitalization:
                              TextCapitalization.words, // Capitalize text
                          inputFormatters: [
                            CapitalizeWordsFormatter(), // <-- Added your custom formatter
                          ],
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                          ),
                          validator: (value) => value?.isEmpty == true
                              ? 'First name is required'
                              : null,
                        ),
                      ),
                      _spacedField(
                        TextFormField(
                          controller: _lastNameController,
                          textCapitalization:
                              TextCapitalization.words, // Capitalize text
                          inputFormatters: [
                            CapitalizeWordsFormatter(), // <-- Added your custom formatter
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                          ),
                          validator: (value) => value?.isEmpty == true
                              ? 'Last name is required'
                              : null,
                        ),
                      ),
                      _spacedField(
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
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
                      _spacedField(
                        TextFormField(
                          controller: _mobileController,
                          decoration: const InputDecoration(
                            labelText: 'Mobile',
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
                      _spacedField(
                        TextFormField(
                          controller: _dobController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                          ),
                          onTap: _pickDate,
                        ),
                      ),

                      // Only show guardian information if user is under 18
                      if (!_isUserAdult) ...[
                        _spacedField(
                          TextFormField(
                            controller: _guardianNameController,
                            textCapitalization:
                                TextCapitalization.words, // Capitalize text
                            inputFormatters: [
                              CapitalizeWordsFormatter(), // <-- Added your custom formatter
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Guardian Name',
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
                      _spacedField(
                        TextFormField(
                          controller: _addressController,
                          textCapitalization:
                              TextCapitalization.words, // Capitalize text
                          inputFormatters: [
                            CapitalizeWordsFormatter(), // <-- Added your custom formatter
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Address',
                          ),
                          validator: (value) => value?.isEmpty == true
                              ? 'Address is required'
                              : null,
                        ),
                      ),
                      TextFormField(
                        controller: _pincodeController,
                        decoration: const InputDecoration(labelText: 'Pincode'),
                        keyboardType: TextInputType.number,
                        validator: _validatePincode,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 6,

                        onChanged: (value) {
                          if (value.length == 6) {
                            _hasUserChangedPincode = true; // 🔑 user intent
                            _fetchAddressFromPincode(value);
                          }
                        },
                      ),
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
                            label: const Text('City'),
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
                            label: const Text('State'),
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
                            label: const Text('Country'),
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
                          decoration: const InputDecoration(
                            labelText: 'Are you a professional choreographer?',
                          ),
                        ),
                      ),

                      if (_isProfessional == 'Yes')
                        _spacedField(
                          TextFormField(
                            controller: _experienceController,
                            decoration: const InputDecoration(
                              labelText: 'Experience (in years)',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly, // ✅ Only numbers allowed
                            ],
                          ),
                        ),

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
                                SizedBox(
                                  width: 6,
                                ), // spacing between text and icon
                                Icon(
                                  Icons.add_circle,
                                  color: Color(0xFF3A5ED4),
                                  size: 26, // 🔥 bigger icon
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
                          onPressed: _isSubmitting
                              ? null
                              : _showUpdateConfirmation,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF3A5ED4),
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
                                  "Update Profile",
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
      print('Error building EditProfileScreen: $e');
      return Scaffold(
        appBar: AppBar(title: const Text("Edit Profile")),
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
