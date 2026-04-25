// In batch_model.dart
import 'package:dancekatta/models/branch_model.dart'; // Add this line to import BranchModel
import 'package:dancekatta/services/branches_service.dart'; // Import BranchesService for fetching branch details

class BatchModel {
  final String id;
  final String batchName;
  final String trainer;
  final String level;
  final String branch;
  final String style;
  final List<String> days;
  final String fee;
  final int capacity;
  final String? status;
  final List<String> enrolledStudents;
  final DateTime fromDate;
  final DateTime toDate;
  final String startTime;
  final String endTime;
  final String studioName;
  final String? studioId;

  final String? levelName;
  final String? branchName;
  final String? styleName;
  final String? trainerName;
  final String? branchAddress;
  final String? branchContactNo;
  // ✅ FIX: The backend sends 'image', so the Flutter model should match.
  final String? image;
  final BranchModel? branchObject;

  BatchModel({
    required this.id,
    required this.batchName,
    required this.trainer,
    required this.level,
    required this.branch,
    required this.style,
    required this.days,
    required this.fee,
    required this.capacity,
    required this.enrolledStudents,
    required this.fromDate,
    required this.toDate,
    required this.startTime,
    required this.endTime,
    required this.studioName,
    this.studioId,
    this.levelName,
    this.branchName,
    this.styleName,
    this.trainerName,
    this.branchAddress,
    this.branchContactNo,
    // ✅ FIX: Use 'image' here as well.
    this.image,
    this.branchObject,
    this.status,
  });

  factory BatchModel.fromJson(
    Map<String, dynamic> json, {
    BranchModel? branchObject,
  }) {
    try {
      // ID
      final id = json['_id'] is Map
          ? json['_id']['\$oid'] ?? ''
          : json['_id']?.toString() ?? '';

      final style = json['style'] is Map
          ? json['style']['_id']?.toString() ?? ''
          : json['style']?.toString() ?? '';
      final styleName = json['style'] is Map
          ? json['style']['name']?.toString()
          : json['styleName']?.toString() ?? style;

      final level = json['level'] is Map
          ? json['level']['_id']?.toString() ?? ''
          : json['level']?.toString() ?? '';
      final levelName = json['level'] is Map
          ? json['level']['name']?.toString()
          : json['levelName']?.toString() ?? level;

      // Branch
      String branch = '';
      String? branchName;
      String? branchAddress;
      String? branchContactNo;
      // ✅ FIX: Add a variable to hold the image URL.
      String? branchImage;

      if (json['branch'] is Map) {
        final branchMap = json['branch'];
        branch = branchMap['_id']?.toString() ?? '';
        branchName =
            branchMap['branchName']?.toString() ??
            branchMap['name']?.toString() ??
            'Unknown Branch';
        branchAddress =
            branchMap['branchAddress']?.toString() ??
            branchMap['address']?.toString() ??
            'Address not available';
        branchContactNo =
            branchMap['contactNumber']?.toString() ??
            branchMap['contactNo']?.toString() ??
            'Contact not available';
        // ✅ FIX: Extract the image URL.
        branchImage = branchMap['image']?.toString();
      } else {
        // ✅ Preserve plain string like "Unknown Location"
        branch = json['branch']?.toString() ?? '';
        branchName = json['branchName']?.toString() ?? branch;
        branchAddress =
            json['branchAddress']?.toString() ?? 'Address not available';
        branchContactNo =
            json['branchContactNo']?.toString() ?? 'Contact not available';
      }

      // Trainer
      String trainer = '';
      String? trainerName;

      // 1️⃣ If 'trainer' is a string, use it
      if (json['trainer'] != null &&
          json['trainer'] is String &&
          json['trainer'].toString().trim().isNotEmpty) {
        trainer = json['trainer'].toString().trim();
        trainerName = trainer;
      }
      // 2️⃣ If 'trainer' is a Map, parse object
      else if (json['trainer'] is Map) {
        final trainerMap = json['trainer'];
        String name = '';
        if (trainerMap['firstName'] != null)
          name += trainerMap['firstName'].toString();
        if (trainerMap['lastName'] != null)
          name += ' ' + trainerMap['lastName'].toString();
        name = name.trim();
        if (name.isNotEmpty)
          trainerName = name;
        else if (trainerMap['name'] != null &&
            trainerMap['name'].toString().trim().isNotEmpty) {
          trainerName = trainerMap['name'].toString();
        }
      }
      // 3️⃣ If still null or "unknown", try trainerName from JSON
      if ((trainerName == null ||
              trainerName.trim().isEmpty ||
              trainerName.toLowerCase() == 'unknown') &&
          json['trainerName'] != null &&
          json['trainerName'].toString().trim().isNotEmpty &&
          json['trainerName'].toString().trim().toLowerCase() != 'unknown') {
        trainerName = json['trainerName'].toString();
      }
      // 4️⃣ Fallback
      if (trainerName == null ||
          trainerName.trim().isEmpty ||
          trainerName.toLowerCase() == 'unknown') {
        trainerName = 'Unknown Trainer';
      }

      // 5️⃣ Extra check if trainerName is still "Unknown Trainer"
      if (trainerName.toLowerCase() == 'unknown trainer') {
        // Example: check another field that backend might send
        if (json['realTrainerName'] != null &&
            json['realTrainerName'].toString().trim().isNotEmpty) {
          trainerName = json['realTrainerName'].toString().trim();
        }
        // Or check nested trainer object
        else if (json['trainer'] is Map) {
          final t = json['trainer'];
          String name = '';
          if (t['firstName'] != null) name += t['firstName'].toString();
          if (t['lastName'] != null) name += ' ' + t['lastName'].toString();
          if (name.trim().isNotEmpty) trainerName = name.trim();
        }
      }

      // Days - supports List<String>, List<dynamic>, or comma-separated string
      final List<String> days = (() {
        final raw = json['days'];
        if (raw is List) {
          return raw.map((e) => e.toString()).toList();
        } else if (raw is String) {
          return raw.split(',').map((e) => e.trim()).toList();
        }
        return <String>[];
      })();

      // Enrolled Students - supports List<String> and List<Map>
      final List<String> enrolledStudents = (() {
        final raw = json['enrolled_students'];
        if (raw is List) {
          return raw.map((e) {
            if (e is Map && e.containsKey('\$oid')) {
              return e['\$oid'].toString();
            }
            return e.toString();
          }).toList();
        }
        return <String>[]; // default empty
      })();

      // Dates
      DateTime fromDate = DateTime.now();
      DateTime toDate = DateTime.now();

      if (json['fromDate'] is Map && json['fromDate']['\$date'] != null) {
        if (json['fromDate']['\$date']['\$numberLong'] != null) {
          fromDate = DateTime.fromMillisecondsSinceEpoch(
            int.parse(json['fromDate']['\$date']['\$numberLong']),
          );
        }
      } else if (json['fromDate'] is String) {
        fromDate = DateTime.tryParse(json['fromDate']) ?? DateTime.now();
      }

      if (json['toDate'] is Map && json['toDate']['\$date'] != null) {
        if (json['toDate']['\$date']['\$numberLong'] != null) {
          toDate = DateTime.fromMillisecondsSinceEpoch(
            int.parse(json['toDate']['\$date']['\$numberLong']),
          );
        }
      } else if (json['toDate'] is String) {
        toDate = DateTime.tryParse(json['toDate']) ?? DateTime.now();
      }

      return BatchModel(
        id: id,
        batchName: json['batchName']?.toString() ?? 'Unknown Batch',
        trainer: trainer,
        level: level,
        branch: branch,
        branchObject: branchObject,
        style: style,
        days: days,
        fee: json['fee']?.toString() ?? '0',
        capacity: int.tryParse(json['capacity']?.toString() ?? '0') ?? 0,
        enrolledStudents: enrolledStudents,
        fromDate: fromDate,
        toDate: toDate,
        startTime: json['startTime']?.toString() ?? '00:00',
        endTime: json['endTime']?.toString() ?? '00:00',
        studioName: json['studioName']?.toString() ?? 'Unknown Studio',
        studioId: json['studioId']?.toString(),
        status: json['status']?.toString(),
        levelName: levelName,
        styleName: styleName,
        branchName: branchName,
        branchAddress: branchAddress,
        trainerName: trainerName,
        branchContactNo: branchContactNo,
        // ✅ FIX: Use the new variable.
        image: branchImage,
      );
    } catch (e) {
      print('❌ Error parsing BatchModel: $e');
      print('📦 JSON data: $json');
      return BatchModel(
        id: '',
        batchName: 'Error Loading Batch',
        trainer: 'Unknown',
        level: '',
        branch: '',
        style: '',
        days: [],
        fee: '0',
        capacity: 0,
        enrolledStudents: [],
        fromDate: DateTime.now(),
        toDate: DateTime.now(),
        startTime: '00:00',
        endTime: '00:00',
        studioName: 'Unknown Studio',
        studioId: null,
        status: null,
        levelName: null,
        styleName: null,
        branchName: null,
        branchAddress: null,
        trainerName: null,
        branchContactNo: null,
        // ✅ FIX: Set default to null.
        image: null,
      );
    }
  }

  // Add this getter for compatibility with code expecting batchData
  Map<String, dynamic> get batchData {
    return {
      '_id': id,
      'batchName': batchName,
      'trainer': trainer,
      'level': level,
      'branch': branch,
      'style': style,
      'days': days,
      'fee': fee,
      'capacity': capacity,
      'enrolled_students': enrolledStudents,
      'fromDate': fromDate,
      'toDate': toDate,
      'startTime': startTime,
      'endTime': endTime,
      'studioName': studioName,
      'studioId': studioId,
      'status': status,
      'levelName': levelName,
      'branchName': branchName,
      'styleName': styleName,
      'trainerName': trainerName,
      'branchAddress': branchAddress,
      'branchContactNo': branchContactNo,
      'image': image,
      'branchObject': branchObject,
    };
  }
}
