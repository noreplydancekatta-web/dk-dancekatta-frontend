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
import 'SignupScreenPart2.dart'; // or the correct path to SignupScreenPart2

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
        .map((word) =>
            word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                : '')
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

  // Dropdown controllers
  String? _selectedCity;
  String? _selectedState;
  String? _selectedCountry;

  String? userId; // For inline error message
  String? _uploadedProfilePhoto; // will store uploaded file path from backend
  File? _profileImage;
  bool _showGuardianFields = false;

  String? emailError; // For inline email error message
  bool isCheckingEmail = false; // Optional if you want to show a loading spinner while checking

  // Add error variables for dropdowns
  String? _cityError;
  String? _stateError;
  String? _countryError;

  List<String> _cities = [];
  List<String> _states = [];
  List<String> _countries = [];

  // Sample data for dropdowns (replace with your actual data)
  // final List<String> _cities = ['Mumbai', 'Delhi', 'Bangalore', 'Hyderabad'];
  // final List<String> _states = [
  //   'Maharashtra',
  //   'Delhi',
  //   'Karnataka',
  //   'Telangana',
  // ];
  // final List<String> _countries = ['India', 'USA', 'UK', 'Canada'];

  @override
  void initState() {
    super.initState();
    _fetchCities();
    _fetchStates();
    _fetchCountries();
  }

  Future<void> checkEmailExists(String email) async {
    if (email.isEmpty || !email.contains('@')) return;

    setState(() => isCheckingEmail = true);

    try {
      final response = await http.get(
        Uri.parse(
          "http://147.93.19.17:5002/api/users/email/${email.toLowerCase()}",
        ),
      );

      if (response.statusCode == 200) {
        // Email already exists
        setState(() {
          emailError = 'This email is already registered';
        });
      } else {
        setState(() {
          emailError = null; // email is free
        });
      }
    } catch (e) {
      print('Email check error: $e');
    } finally {
      setState(() => isCheckingEmail = false);
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
      context: context, // ✅ correct BuildContext
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

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path); // just preview
      });
    }
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
      return relativePath; // ✅ relative path only
    } catch (e) {
      print("Image upload error: $e");
      return null;
    }
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidateMode, // Disable auto validation
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
                      CrossAxisAlignment.start, // 👈 left align text
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
                      textCapitalization:
                          TextCapitalization.words, // Capitalize text
                          inputFormatters: [
                          CapitalizeWordsFormatter(), // <-- Added your custom formatter 
                          ],
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
                      textCapitalization:
                          TextCapitalization.words, // Capitalize text
                        inputFormatters: [
                          CapitalizeWordsFormatter(), // <-- Added your custom formatter 
                          ],
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
                        // Remove errorText here!
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email is required';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Enter a valid email';
                        }
                        // Show this only after backend check completed and only if error present
                        if (emailError != null && emailError!.isNotEmpty) {
                          return emailError;
                        }
                        return null;
                      },
                      onFieldSubmitted: (email) async {
                        await checkEmailExists(email.trim());
                        setState(() {}); // Revalidate field after backend check
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

                    // Alternate Mobile - Fixed Alignment
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
                          height: 48, // Fixed height to match text field
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: const Text(
                              '+91',
                              style: TextStyle(fontSize: 16),
                            ),
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

                    // Conditional Guardian Fields
                    if (_showGuardianFields) ...[
                      buildRequiredLabel('Guardian\'s name'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _guardianNameController,
                        textCapitalization:
                            TextCapitalization.words, // Capitalize text
                            inputFormatters: [
                          CapitalizeWordsFormatter(), // <-- Added your custom formatter 
                          ],
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

                      // Guardian Mobile - Fixed Alignment
                      buildRequiredLabel('Guardian\'s mobile number'),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 48, // Fixed height to match text field
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: const Text(
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
                    // Address Section
                    buildRequiredLabel('House/FlatNo.'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      textCapitalization:
                          TextCapitalization.words, // Capitalize text
                          inputFormatters: [
                          CapitalizeWordsFormatter(), // <-- Added your custom formatter 
                          ],
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

                        // Regex: only allow letters, numbers, spaces, hyphens, and slashes
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
                                dropdownMenuEntries: _cities.map((
                                  String value,
                                ) {
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
                                menuStyle: MenuStyle(
                                  alignment: AlignmentDirectional.bottomStart,
                                  maximumSize: MaterialStateProperty.all<Size>(
                                    const Size.fromHeight(200),
                                  ),
                                ),
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
                        const SizedBox(width: 16),
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
                                dropdownMenuEntries: _states.map((
                                  String value,
                                ) {
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
                                menuStyle: MenuStyle(
                                  alignment: AlignmentDirectional.bottomStart,
                                  maximumSize: MaterialStateProperty.all<Size>(
                                    const Size.fromHeight(200),
                                  ),
                                ),
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
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Pincode and Country Row
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
                                dropdownMenuEntries: _countries.map((
                                  String value,
                                ) {
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
                                menuStyle: MenuStyle(
                                  alignment: AlignmentDirectional.bottomStart,
                                  maximumSize: MaterialStateProperty.all<Size>(
                                    const Size.fromHeight(200),
                                  ),
                                ),
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
                    const SizedBox(height: 20),

                    // Profile Picture Upload
                    buildRequiredLabel('Upload Profile Picture'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage, // ✅ only previews image now
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
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Upload profile picture',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ✅ Next Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            _autoValidateMode = AutovalidateMode.always;
                          });
                          // Validate dropdowns manually
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

                          // Check email again if not checked
                          if (_emailController.text.isNotEmpty &&
                              emailError == null) {
                            await checkEmailExists(
                              _emailController.text.trim(),
                            );
                          }

                          // Run all form field validators
                          if (_formKey.currentState!.validate() &&
                              dropdownsValid &&
                              emailError == null) {
                            // Extra check for email already registered
                            if (emailError != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(emailError!)),
                              );
                              return;
                            }

                            // Profile picture required
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

                            // ✅ Upload profile photo first
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

                            // ✅ Navigate to SignupScreenPart2 with all collected data
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
                            // Show error if any required field is missing
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
