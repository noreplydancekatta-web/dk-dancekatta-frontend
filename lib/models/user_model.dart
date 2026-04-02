// Complete UserModel with ALL required fields
// File: lib/models/user_model.dart

class UserModel {
  final String? id;
  final String firstName;
  final String lastName;
  final String mobile;
  final String email;
  final String? profilePhoto;

  // Profile fields
  final String? altMobile;
  final String? dateOfBirth;
  final String? guardianName;
  final String? guardianMobile;
  final String? guardianEmail;
  final String? address;
  final String city;
  final String state;
  final String? country;
  final String? pincode;

  // Social media
  final String? youtube;
  final String? facebook;
  final String? instagram;

  // Professional info
  final String? isProfessional;
  final bool isProfessionalChoreographer;
  final String? experience;
  final List<Skill>? skills;

  // Studio info
  final String? studioStatus;
  final bool? isStudioOwner;
  final bool? studioCreated;

  // Status
  final String? status; // "Active" or "Disabled"
  final bool isProfileFullyComplete;

  UserModel({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.mobile,
    required this.email,
    this.profilePhoto,
    this.altMobile,
    this.dateOfBirth,
    this.guardianName,
    this.guardianMobile,
    this.guardianEmail,
    this.address,
    required this.city,
    required this.state,
    this.country,
    this.pincode,
    this.youtube,
    this.facebook,
    this.instagram,
    this.isProfessional,
    required this.isProfessionalChoreographer,
    this.experience,
    this.skills,
    this.studioStatus,
    this.isStudioOwner,
    this.studioCreated,
    this.status,
    required this.isProfileFullyComplete,
  });

  // ✅ COPY WITH METHOD
  UserModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? mobile,
    String? email,
    String? profilePhoto,
    String? altMobile,
    String? dateOfBirth,
    String? guardianName,
    String? guardianMobile,
    String? guardianEmail,
    String? address,
    String? city,
    String? state,
    String? country,
    String? pincode,
    String? youtube,
    String? facebook,
    String? instagram,
    String? isProfessional,
    bool? isProfessionalChoreographer,
    String? experience,
    List<Skill>? skills,
    String? studioStatus,
    bool? isStudioOwner,
    bool? studioCreated,
    String? status,
    bool? isProfileFullyComplete,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      altMobile: altMobile ?? this.altMobile,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      guardianName: guardianName ?? this.guardianName,
      guardianMobile: guardianMobile ?? this.guardianMobile,
      guardianEmail: guardianEmail ?? this.guardianEmail,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      pincode: pincode ?? this.pincode,
      youtube: youtube ?? this.youtube,
      facebook: facebook ?? this.facebook,
      instagram: instagram ?? this.instagram,
      isProfessional: isProfessional ?? this.isProfessional,
      isProfessionalChoreographer:
          isProfessionalChoreographer ?? this.isProfessionalChoreographer,
      experience: experience ?? this.experience,
      skills: skills ?? this.skills,
      studioStatus: studioStatus ?? this.studioStatus,
      isStudioOwner: isStudioOwner ?? this.isStudioOwner,
      studioCreated: studioCreated ?? this.studioCreated,
      status: status ?? this.status,
      isProfileFullyComplete:
          isProfileFullyComplete ?? this.isProfileFullyComplete,
    );
  }

  // ✅ FROM JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName'] ?? '';
    final lastName = json['lastName'] ?? '';
    final mobile = json['mobile'] ?? '';
    final email = json['email'] ?? '';
    final profilePhoto = json['profilePhoto'];
    final dateOfBirth = json['dateOfBirth'];
    final address = json['address'];
    final city = json['city'] ?? '';
    final state = json['state'] ?? '';
    final country = json['country'];
    final pincode = json['pincode'];
    final isProfessional = json['isProfessional'];

    // ✅ Compute locally — no backend dependency
    final isProfileFullyComplete =
        firstName.isNotEmpty &&
        lastName.isNotEmpty &&
        mobile.isNotEmpty &&
        email.isNotEmpty &&
        (profilePhoto != null && profilePhoto.toString().isNotEmpty) &&
        (dateOfBirth != null && dateOfBirth.toString().isNotEmpty) &&
        (address != null && address.toString().isNotEmpty) &&
        city.isNotEmpty &&
        state.isNotEmpty &&
        (country != null && country.toString().isNotEmpty) &&
        (pincode != null && pincode.toString().isNotEmpty) &&
        (isProfessional != null && isProfessional.toString().isNotEmpty);

    return UserModel(
      id: json['_id'] ?? json['id'],
      firstName: firstName,
      lastName: lastName,
      mobile: mobile,
      email: email,
      profilePhoto: profilePhoto,
      altMobile: json['altMobile'],
      dateOfBirth: dateOfBirth,
      guardianName: json['guardianName'],
      guardianMobile: json['guardianMobile'],
      guardianEmail: json['guardianEmail'],
      address: address,
      city: city,
      state: state,
      country: country,
      pincode: pincode,
      youtube: json['youtube'],
      facebook: json['facebook'],
      instagram: json['instagram'],
      isProfessional: isProfessional,
      isProfessionalChoreographer:
          isProfessional == 'Yes' ||
          json['isProfessionalChoreographer'] == true,
      experience: json['experience'],
      skills: json['skills'] != null
          ? (json['skills'] as List).map((s) => Skill.fromJson(s)).toList()
          : null,
      studioStatus: json['studioStatus'],
      isStudioOwner: json['isStudioOwner'],
      studioCreated: json['studioCreated'],
      status: json['status'],
      isProfileFullyComplete: isProfileFullyComplete, // ✅ computed locally
    );
  }

  // ✅ TO JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'firstName': firstName,
      'lastName': lastName,
      'mobile': mobile,
      'email': email,
      if (profilePhoto != null) 'profilePhoto': profilePhoto,
      if (altMobile != null) 'altMobile': altMobile,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      if (guardianName != null) 'guardianName': guardianName,
      if (guardianMobile != null) 'guardianMobile': guardianMobile,
      if (guardianEmail != null) 'guardianEmail': guardianEmail,
      if (address != null) 'address': address,
      'city': city,
      'state': state,
      if (country != null) 'country': country,
      if (pincode != null) 'pincode': pincode,
      if (youtube != null) 'youtube': youtube,
      if (facebook != null) 'facebook': facebook,
      if (instagram != null) 'instagram': instagram,
      if (isProfessional != null) 'isProfessional': isProfessional,
      'isProfessionalChoreographer': isProfessionalChoreographer,
      if (experience != null) 'experience': experience,
      if (skills != null) 'skills': skills!.map((s) => s.toJson()).toList(),
      if (studioStatus != null) 'studioStatus': studioStatus,
      if (isStudioOwner != null) 'isStudioOwner': isStudioOwner,
      if (studioCreated != null) 'studioCreated': studioCreated,
      if (status != null) 'status': status,
      'isProfileComplete': isProfileFullyComplete,
    };
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $firstName $lastName, email: $email, studioStatus: $studioStatus)';
  }
}

// ✅ Skill Model
class Skill {
  final String style;
  final String level;

  Skill({required this.style, required this.level});

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(style: json['style'] ?? '', level: json['level'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'style': style, 'level': level};
  }

  @override
  String toString() => 'Skill(style: $style, level: $level)';
}
