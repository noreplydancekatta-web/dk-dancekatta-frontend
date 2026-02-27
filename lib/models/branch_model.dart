class BranchModel {
  final String id;
  final String name;
  final String address;   // Full address for Batch Detail screen
  final String area;      // ✅ Area for Explore card
  final String mapLink;
  final String contactNo;
  final String? image;    // Updated to a single nullable String

  BranchModel({
    required this.id,
    required this.name,
    required this.address,
    required this.area,
    required this.mapLink,
    required this.contactNo,
    this.image,
  });

  factory BranchModel.fromJson(dynamic json) {
    try {
      print('🔄 Parsing BranchModel...');
      print('📦 Raw JSON: $json');

      // If branch is just a String (ID), return minimal model
      if (json is String) {
        return BranchModel(
          id: json,
          name: 'Unknown Branch',
          address: 'Address not available',
          area: 'Unknown Location',
          mapLink: '',
          contactNo: 'Not Available',
          image: null,
        );
      }

      if (json is! Map<String, dynamic>) {
        throw Exception('Invalid branch JSON format');
      }

      // ✅ Parse ID
      String id = '';
      if (json['_id'] is Map && json['_id'].containsKey('\$oid')) {
        id = json['_id']['\$oid'].toString();
      } else if (json['_id'] is String) {
        id = json['_id']!;
      } else if (json['id'] is String) {
        id = json['id']!;
      }

      // ✅ Name
      String name = 'Unknown Branch';
      if ((json['name'] ?? '').toString().trim().isNotEmpty) {
        name = json['name'].toString();
      } else if ((json['branchName'] ?? '').toString().trim().isNotEmpty) {
        name = json['branchName'].toString();
      }

      // ✅ Address
      String address = 'Address not available';
      if ((json['address'] ?? '').toString().trim().isNotEmpty) {
        address = json['address'].toString();
      } else if ((json['branchAddress'] ?? '').toString().trim().isNotEmpty) {
        address = json['branchAddress'].toString();
      }

      // ✅ Area
      String area = 'Unknown Location';
      if ((json['area'] ?? '').toString().trim().isNotEmpty) {
        area = json['area'].toString();
      }

      // ✅ Contact
      String contactNo = 'Not Available';
      if ((json['contactNo'] ?? '').toString().trim().isNotEmpty) {
        contactNo = json['contactNo'].toString();
      }

      // ✅ Map Link
      String mapLink = '';
      if ((json['mapLink'] ?? '').toString().trim().isNotEmpty) {
        mapLink = json['mapLink'].toString();
      }

      // ✅ Image
      String? image;
      if (json['image'] != null) {
        image = json['image'].toString();
      }

      return BranchModel(
        id: id,
        name: name,
        address: address,
        area: area,
        mapLink: mapLink,
        contactNo: contactNo,
        image: image,
      );
    } catch (e) {
      print('❌ Error parsing BranchModel: $e');
      return BranchModel(
        id: '',
        name: 'Unknown Branch',
        address: 'Address not available',
        area: 'Unknown Location',
        mapLink: '',
        contactNo: 'Not Available',
        image: null,
      );
    }
  }
}