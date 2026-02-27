import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/studio_model.dart';

late DbCollection studioCollection;

class MongoDBConnection {
  static late DbCollection batchCollection; // ✅ Added for batches
  static final MongoDBConnection _instance = MongoDBConnection._internal();
  static const _mongoUrl =
      "mongodb+srv://siony21chaudhari:MyNewPassword123@cluster0.ysj38ta.mongodb.net/dance_katta_db?retryWrites=true&w=majority&appName=Cluster0";

  static const _studioCollectionName = 'studios';
  static const _batchCollectionName = 'batches'; // ✅ Name of the batches collection

  Db? _db;

  MongoDBConnection._internal();

  static MongoDBConnection get instance => _instance;

  Future<void> connect() async {
    try {
      _db = await Db.create(_mongoUrl);
      await _db!.open();

      // ✅ Initialize both studio and batch collections
      studioCollection = _db!.collection(_studioCollectionName);
      batchCollection = _db!.collection(_batchCollectionName);

      log('✅ Connected to MongoDB and loaded collections');
    } catch (e) {
      log('❌ MongoDB connection error: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    try {
      await _db?.close();
      log('MongoDB connection closed');
    } catch (e) {
      log('Error closing MongoDB connection: $e');
      rethrow;
    }
  }

  // ===========================
  // ===== CRUD FUNCTIONS =====
  // ===========================

  Future<String> insertStudio(StudioModel studio) async {
    try {
      final result = await studioCollection.insertOne(studio.toJson());
      return result.isSuccess
          ? 'Studio registered successfully'
          : 'Failed to register studio';
    } catch (e) {
      log('Error inserting studio: $e');
      rethrow;
    }
  }

  Future<StudioModel?> getStudioById(ObjectId id) async {
    try {
      final result = await studioCollection.findOne(where.id(id));
      return result != null ? StudioModel.fromJson(result) : null;
    } catch (e) {
      log('Error getting studio: $e');
      rethrow;
    }
  }

  Future<List<StudioModel>> getAllStudios() async {
    try {
      final results = await studioCollection.find().toList();
      return results.map((doc) => StudioModel.fromJson(doc)).toList();
    } catch (e) {
      log('Error getting all studios: $e');
      rethrow;
    }
  }

  Future<String> updateStudio(StudioModel studio) async {
    try {
      final result = await studioCollection.updateOne(
        where.id(studio.id),
        modify
            .set('studioName', studio.studioName)
            .set('registeredAddress', studio.registeredAddress)
            .set('contactEmail', studio.contactEmail)
            .set('contactNumber', studio.contactNumber)
            .set('gstNumber', studio.gstNumber)
            .set('panNumber', studio.panNumber)
            .set('aadharFrontPhoto', studio.aadharFrontPhoto)
            .set('aadharBackPhoto', studio.aadharBackPhoto)
            .set('bankAccountNumber', studio.bankAccountNumber)
            .set('bankIfscCode', studio.bankIfscCode)
            .set('studioIntroduction', studio.studioIntroduction)
            .set('studioPhotos', studio.studioPhotos)
            .set('logoUrl', studio.logoUrl)
            .set('studioWebsite', studio.studioWebsite)
            .set('studioFacebook', studio.studioFacebook)
            .set('studioYoutube', studio.studioYoutube)
            .set('studioInstagram', studio.studioInstagram)
            .set('updatedAt', DateTime.now())
            .set('status', studio.status),
      );
      return result.isSuccess
          ? 'Studio updated successfully'
          : 'Failed to update studio';
    } catch (e) {
      log('Error updating studio: $e');
      rethrow;
    }
  }

  Future<String> deleteStudio(ObjectId id) async {
    try {
      final result = await studioCollection.deleteOne(where.id(id));
      return result.isSuccess
          ? 'Studio deleted successfully'
          : 'Failed to delete studio';
    } catch (e) {
      log('Error deleting studio: $e');
      rethrow;
    }
  }

  // ===========================
  //   NEW: Studios + Derived Fields
  // ===========================
  Future<List<Map<String, dynamic>>> fetchStudiosWithDerivedFields() async {
    try {
      final studios = await studioCollection.find().toList();

      final List<Map<String, dynamic>> enrichedStudios = [];
      for (var studio in studios) {
        final studioId = studio['_id'] as ObjectId;

        // Owner name (dummy if not linked)
        final ownerName = studio['ownerName'] ?? 'Unknown Owner';

        // Branch count (other studios with same ownerId)
        final branchCount = await studioCollection.count(where.eq('ownerId', studio['ownerId']));

        // Batch count
        final batchCount = await batchCollection.count(where.eq('studioId', studioId));

        enrichedStudios.add({
          ...studio,
          'ownerName': ownerName,
          'branchCount': branchCount,
          'batchCount': batchCount,
        });
      }

      return enrichedStudios;
    } catch (e) {
      log('Error fetching studios with derived fields: $e');
      rethrow;
    }
  }
}
