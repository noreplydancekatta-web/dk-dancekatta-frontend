//final updated
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../services/upload_service.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '/utils/url_helper.dart';
import 'SignupScreenPart2.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
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

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _altMobileController = TextEditingController();
  final TextEditingController _guardianNameController = TextEditingController();
  final TextEditingController _guardianMobileController =
      TextEditingController();
  final TextEditingController _guardianEmailController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  String? _selectedCity;
  String? _selectedState;
  String? _selectedCountry;

  String? userId;
  String? _uploadedProfilePhoto;
  File? _profileImage;
  bool _showGuardianFields = false;

  String? emailError;
  bool isCheckingEmail = false;

  String? _cityError;
  String? _stateError;
  String? _countryError;

  List<String> _cities = [];
  List<String> _states = [];
  List<String> _countries = [];

  @override
  void initState() {
    super.initState();
    _fetchCities();
    _fetchStates();
    _fetchCountries();
  }

  Future<void> checkEmailExists(String email) async {
    if (email.isEmpty || !email.contains('@')) return;

    setState(() {
      isCheckingEmail = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          "http://147.93.19.17:5002/api/users/email/${email.toLowerCase()}",
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          if (data['exists'] == true) {
            emailError = "This email is already registered";
          } else {
            emailError = null;
          }
        });
      } else {
        setState(() {
          emailError = null;
        });
      }
    } catch (e) {
      debugPrint("Email check error: $e");
      setState(() {
        emailError = null;
      });
    } finally {
      setState(() {
        isCheckingEmail = false;
      });
    }
  }

  Future<void> _fetchCities() async {
    try {
      final response = await http.get(
        Uri.parse('http://147.93.19.17:5002/api/cities'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            _cities = List<String>.from(data.map((city) => city['name'] ?? ''));
          });
        }
      }
    } catch (e) {
      print('Error fetching cities: $e');
    }
  }

  Future<void> _fetchStates() async {
    try {
      final response = await http.get(
        Uri.parse('http://147.93.19.17:5002/api/states'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            _states = List<String>.from(
              data.map((state) => state['name'] ?? ''),
            );
          });
        }
      }
    } catch (e) {
      print('Error fetching states: $e');
    }
  }

  Future<void> _fetchCountries() async {
    try {
      final response = await http.get(
        Uri.parse('http://147.93.19.17:5002/api/countries'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            _countries = List<String>.from(
              data.map((country) => country['name'] ?? ''),
            );
          });
        }
      }
    } catch (e) {
      print('Error fetching countries: $e');
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final today = DateTime.now();
      final age =
          today.year -
          picked.year -
          ((today.month > picked.month ||
                  (today.month == picked.month && today.day >= picked.day))
              ? 0
              : 1);

      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
        _showGuardianFields = age < 18;
      });
    }
  }

  // ✅ Updated: shows bottom sheet with Camera + Gallery options
  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Profile Picture',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF3A5ED4),
                    child: Icon(Icons.camera_alt, color: Colors.white),
                  ),
                  title: const Text('Take a Photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    );
                    if (pickedFile != null) {
                      setState(() {
                        _profileImage = File(pickedFile.path);
                      });
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF3A5ED4),
                    child: Icon(Icons.photo_library, color: Colors.white),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    );
                    if (pickedFile != null) {
                      setState(() {
                        _profileImage = File(pickedFile.path);
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildRequiredLabel(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black,
        ),
        children: const [
          TextSpan(
            text: '*',
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadProfileImage(File imageFile) async {
    try {
      final relativePath = await UploadService.uploadImage(
        imageFile,
        "api/users/profile-image",
      );
      return relativePath;
    } catch (e) {
      print("Image upload error: $e");
      return null;
    }
  }

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

          final city = postOffice['Name'] ?? '';
          final state = postOffice['State'] ?? '';
          final country = postOffice['Country'] ?? 'India';

          setState(() {
            if (!_cities.contains(city) && city.isNotEmpty) {
              _cities.add(city);
            }
            if (!_states.contains(state) && state.isNotEmpty) {
              _states.add(state);
            }
            if (!_countries.contains(country) && country.isNotEmpty) {
              _countries.add(country);
            }

            _selectedCity = city.isNotEmpty ? city : _selectedCity;
            _selectedState = state.isNotEmpty ? state : _selectedState;
            _selectedCountry = country.isNotEmpty ? country : _selectedCountry;

            _cityError = null;
            _stateError = null;
            _countryError = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidateMode,
          child: Column(
            children: [
              // Header
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

              // Form Content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Personal Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // First Name
                    buildRequiredLabel('First name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [CapitalizeWordsFormatter()],
                      decoration: InputDecoration(
                        hintText: 'Enter first name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'First name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Last Name
                    buildRequiredLabel('Last Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [CapitalizeWordsFormatter()],
                      decoration: InputDecoration(
                        hintText: 'Enter last name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Last name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Email
                    buildRequiredLabel('Enter Email ID'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: 'Enter Email ID',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) {
                        setState(() {
                          emailError = null;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email is required';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Enter a valid email';
                        }
                        if (emailError != null) {
                          return emailError;
                        }
                        return null;
                      },
                      onFieldSubmitted: (email) async {
                        await checkEmailExists(email.trim());
                      },
                    ),
                    const SizedBox(height: 20),

                    // Mobile Number
                    buildRequiredLabel('Mobile Number'),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('+91', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _mobileController,
                            decoration: InputDecoration(
                              hintText: 'Enter Mobile Number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Mobile number is required';
                              }
                              if (value.length != 10) {
                                return 'Must be 10 digits';
                              }
                              return null;
                            },
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Alternate Mobile
                    const Text(
                      'Alternate mobile number',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('+91', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _altMobileController,
                            decoration: InputDecoration(
                              hintText: 'Enter Mobile Number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Date of Birth
                    buildRequiredLabel('Date of Birth'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _selectDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _dateController,
                          decoration: InputDecoration(
                            hintText: 'Select Date of Birth',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Date of birth is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Guardian Fields (conditional)
                    if (_showGuardianFields) ...[
                      buildRequiredLabel('Guardian\'s name'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _guardianNameController,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [CapitalizeWordsFormatter()],
                        decoration: InputDecoration(
                          hintText: 'Enter name of guardian',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        validator: (value) {
                          if (_showGuardianFields &&
                              (value == null || value.isEmpty)) {
                            return 'Guardian name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      buildRequiredLabel('Guardian\'s mobile number'),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text(
                                '+91',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _guardianMobileController,
                              decoration: InputDecoration(
                                hintText: 'Enter Mobile Number',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              validator: (value) {
                                if (_showGuardianFields &&
                                    (value == null || value.isEmpty)) {
                                  return 'Guardian mobile is required';
                                }
                                if (_showGuardianFields &&
                                    value != null &&
                                    value.length != 10) {
                                  return 'Must be 10 digits';
                                }
                                return null;
                              },
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      buildRequiredLabel('Guardian\'s email ID'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _guardianEmailController,
                        decoration: InputDecoration(
                          hintText: 'Enter email ID of Guardian',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        validator: (value) {
                          if (_showGuardianFields &&
                              (value == null || value.isEmpty)) {
                            return 'Guardian email is required';
                          }
                          if (_showGuardianFields &&
                              value != null &&
                              !value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Address
                    buildRequiredLabel('House/FlatNo.'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [CapitalizeWordsFormatter()],
                      decoration: InputDecoration(
                        hintText: 'Enter full address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Address is required';
                        }
                        final pattern = RegExp(r'^[a-zA-Z0-9\s\-/]+$');
                        if (!pattern.hasMatch(value)) {
                          return 'Invalid characters in address';
                        }
                        return null;
                      },
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // City and State Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildRequiredLabel('Pincode'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _pincodeController,
                                decoration: InputDecoration(
                                  hintText: 'Enter pincode',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  counterText: '',
                                ),
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                onChanged: (value) {
                                  if (value.length == 6) {
                                    _fetchAddressFromPincode(value);
                                  }
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Pincode is required';
                                  }
                                  if (value.length != 6) {
                                    return 'Must be 6 digits';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // CITY
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildRequiredLabel('City'),
                              const SizedBox(height: 8),
                              DropdownMenu<String>(
                                initialSelection: _selectedCity,
                                expandedInsets: EdgeInsets.zero,
                                inputDecorationTheme: InputDecorationTheme(
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                ),
                                hintText: 'Select city',
                                dropdownMenuEntries: _cities.map((value) {
                                  return DropdownMenuEntry<String>(
                                    value: value,
                                    label: value,
                                  );
                                }).toList(),
                                onSelected: (newValue) {
                                  setState(() {
                                    _selectedCity = newValue;
                                    _cityError = null;
                                  });
                                },
                              ),
                              if (_cityError != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 4,
                                  ),
                                  child: Text(
                                    _cityError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 🔹 Row 2 → STATE + COUNTRY
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildRequiredLabel('State'),
                              const SizedBox(height: 8),
                              DropdownMenu<String>(
                                initialSelection: _selectedState,
                                expandedInsets: EdgeInsets.zero,
                                inputDecorationTheme: InputDecorationTheme(
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                ),
                                hintText: 'Select state',
                                dropdownMenuEntries: _states.map((value) {
                                  return DropdownMenuEntry<String>(
                                    value: value,
                                    label: value,
                                  );
                                }).toList(),
                                onSelected: (newValue) {
                                  setState(() {
                                    _selectedState = newValue;
                                    _stateError = null;
                                  });
                                },
                              ),
                              if (_stateError != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 4,
                                  ),
                                  child: Text(
                                    _stateError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildRequiredLabel('Country'),
                              const SizedBox(height: 8),
                              DropdownMenu<String>(
                                initialSelection: _selectedCountry,
                                expandedInsets: EdgeInsets.zero,
                                inputDecorationTheme: InputDecorationTheme(
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                ),
                                hintText: 'Select country',
                                dropdownMenuEntries: _countries.map((value) {
                                  return DropdownMenuEntry<String>(
                                    value: value,
                                    label: value,
                                  );
                                }).toList(),
                                onSelected: (newValue) {
                                  setState(() {
                                    _selectedCountry = newValue;
                                    _countryError = null;
                                  });
                                },
                              ),
                              if (_countryError != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 4,
                                  ),
                                  child: Text(
                                    _countryError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ✅ Profile Picture Upload with Camera + Gallery
                    buildRequiredLabel('Upload Profile Picture'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _profileImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  _profileImage!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          size: 32,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(width: 16),
                                        Icon(
                                          Icons.photo_library,
                                          size: 32,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Tap to upload via Camera or Gallery',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Next Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            _autoValidateMode = AutovalidateMode.always;
                          });

                          bool dropdownsValid = true;
                          setState(() {
                            _cityError = _selectedCity == null
                                ? 'City is required'
                                : null;
                            _stateError = _selectedState == null
                                ? 'State is required'
                                : null;
                            _countryError = _selectedCountry == null
                                ? 'Country is required'
                                : null;
                            dropdownsValid =
                                _cityError == null &&
                                _stateError == null &&
                                _countryError == null;
                          });

                          await checkEmailExists(_emailController.text.trim());

                          if (emailError != null) {
                            _formKey.currentState!.validate();
                            return;
                          }

                          if (_formKey.currentState!.validate() &&
                              dropdownsValid &&
                              emailError == null) {
                            if (_profileImage == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please upload a profile picture',
                                  ),
                                ),
                              );
                              return;
                            }

                            String? uploadedPath;
                            try {
                              uploadedPath = await _uploadProfileImage(
                                _profileImage!,
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to upload image: $e'),
                                ),
                              );
                              return;
                            }

                            if (uploadedPath == null || uploadedPath.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to upload image'),
                                ),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SignupScreenPart2(
                                  firstName: _firstNameController.text.trim(),
                                  lastName: _lastNameController.text.trim(),
                                  email: _emailController.text.trim(),
                                  mobile: _mobileController.text.trim(),
                                  altMobile: _altMobileController.text.trim(),
                                  dateOfBirth: _dateController.text.trim(),
                                  guardianName: _guardianNameController.text
                                      .trim(),
                                  guardianMobile: _guardianMobileController.text
                                      .trim(),
                                  guardianEmail: _guardianEmailController.text
                                      .trim(),
                                  address: _addressController.text.trim(),
                                  city: _selectedCity ?? '',
                                  state: _selectedState ?? '',
                                  country: _selectedCountry ?? '',
                                  pincode: _pincodeController.text.trim(),
                                  profilePhoto: uploadedPath,
                                ),
                              ),
                            );
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
      ),
    );
  }
}
