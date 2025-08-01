import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/voucher.dart';
import 'dart:convert'; // Added for jsonEncode

class FirebaseVoucherService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference get _vouchersCollection =>
      _firestore.collection('vouchers');
  static CollectionReference get _redeemedVouchersCollection =>
      _firestore.collection('redeemed_vouchers');
  static CollectionReference get _examsCollection =>
      _firestore.collection('exams');

  /// Generate a new voucher and save it to Firestore
  static Future<Voucher> generateCloudVoucher({
    String? name,
    String? examId,
    Map<String, dynamic>? examData,
    Duration? examExpiryDuration,
  }) async {
    try {
      // Generate unique voucher code
      final code = _generateVoucherCode();

      // Create voucher with 3-month expiry
      final now = DateTime.now();
      final expiryDate = now.add(Duration(days: 90)); // 3 months

      final voucher = Voucher(
        id: '', // Will be set by Firestore
        code: code,
        name: name ?? 'Cloud Voucher',
        examId: examId,
        examData: examData, // Keep for backward compatibility
        examExpiryDuration: examExpiryDuration,
        createdDate: now,
        expiryDate: expiryDate,
      );

      print('Debug: Creating voucher with examData: ${examData != null}');
      print('Debug: ExamData keys: ${examData?.keys.toList()}');
      print(
        'Debug: ExamData questions count: ${examData?['questions']?.length ?? 0}',
      );

      // Save to Firestore
      final voucherJson = voucher.toJson();
      print('Debug: Voucher JSON keys: ${voucherJson.keys.toList()}');
      print('Debug: Voucher JSON examData: ${voucherJson['examData'] != null}');

      // Check size of examData (only if embedded)
      if (voucherJson['examData'] != null) {
        final examDataSize = jsonEncode(voucherJson['examData']).length;
        print('Debug: ExamData size: $examDataSize bytes');
        if (examDataSize > 1000000) {
          // 1MB limit
          print('Debug: WARNING - ExamData is too large for Firestore!');
        }
      }

      final docRef = await _vouchersCollection.add(voucherJson);

      // Update voucher with Firestore ID
      final updatedVoucher = voucher.copyWith(id: docRef.id);

      // Update the document with the ID
      await docRef.update({'id': docRef.id});

      return updatedVoucher;
    } catch (e) {
      throw Exception('Failed to generate cloud voucher: $e');
    }
  }

  /// Store an exam in the cloud
  static Future<String> storeExamInCloud(Map<String, dynamic> examData) async {
    try {
      final docRef = await _examsCollection.add({
        ...examData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to store exam in cloud: $e');
    }
  }

  /// Get an exam from the cloud
  static Future<Map<String, dynamic>?> getExamFromCloud(String examId) async {
    try {
      // First try to find the exam in the user_exams collection
      // We need to search across all users' unlocked exams
      final unlockedSnapshot = await _firestore.collection('user_exams').get();

      for (final userDoc in unlockedSnapshot.docs) {
        final unlockedCollection = userDoc.reference.collection('unlocked');
        final examDoc = await unlockedCollection.doc(examId).get();

        if (examDoc.exists) {
          print('Debug: Found exam in user_exams collection: $examId');
          return examDoc.data() as Map<String, dynamic>;
        }
      }

      // If not found in user_exams, try the exams collection by querying for the examId field
      print('Debug: Searching in exams collection for examId: $examId');
      final querySnapshot = await _examsCollection
          .where('id', isEqualTo: examId)
          .limit(1)
          .get();

      print('Debug: Query returned ${querySnapshot.docs.length} documents');

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        print('Debug: Found exam in exams collection: $examId');
        print('Debug: Document ID: ${doc.id}');
        final data = doc.data() as Map<String, dynamic>?;
        print('Debug: Document data keys: ${data?.keys.toList()}');
        return doc.data() as Map<String, dynamic>;
      }

      print('Debug: Exam not found in any collection: $examId');
      return null;
    } catch (e) {
      print('Error getting exam from cloud: $e');
      return null;
    }
  }

  /// Update an exam in the cloud
  static Future<bool> updateExamInCloud(
    String examId,
    Map<String, dynamic> examData,
  ) async {
    try {
      await _examsCollection.doc(examId).update({
        ...examData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating exam in cloud: $e');
      return false;
    }
  }

  /// Delete an exam from the cloud
  static Future<bool> deleteExamFromCloud(String examId) async {
    try {
      await _examsCollection.doc(examId).delete();
      return true;
    } catch (e) {
      print('Error deleting exam from cloud: $e');
      return false;
    }
  }

  /// Get all exams from the cloud
  static Future<List<Map<String, dynamic>>> getAllCloudExams() async {
    try {
      final querySnapshot = await _examsCollection.get();
      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error getting cloud exams: $e');
      return [];
    }
  }

  /// Validate a voucher against Firestore
  static Future<Voucher?> validateCloudVoucher(String code) async {
    try {
      // Query for the voucher by code
      final querySnapshot = await _vouchersCollection
          .where('code', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null; // Voucher not found
      }

      final doc = querySnapshot.docs.first;
      final voucherData = doc.data() as Map<String, dynamic>;

      print(
        'Debug: Raw voucher data from Firestore: ${voucherData.keys.toList()}',
      );
      print(
        'Debug: Voucher examData from Firestore: ${voucherData['examData'] != null}',
      );
      print(
        'Debug: Voucher examData keys: ${(voucherData['examData'] as Map<String, dynamic>?)?.keys.toList()}',
      );

      // Convert Firestore Timestamps to ISO strings
      if (voucherData['createdDate'] != null) {
        final timestamp = voucherData['createdDate'] as dynamic;
        if (timestamp.toString().contains('Timestamp')) {
          voucherData['createdDate'] = timestamp.toDate().toIso8601String();
        }
      }

      if (voucherData['expiryDate'] != null) {
        final timestamp = voucherData['expiryDate'] as dynamic;
        if (timestamp.toString().contains('Timestamp')) {
          voucherData['expiryDate'] = timestamp.toDate().toIso8601String();
        }
      }

      // Check if voucher has been redeemed
      final redeemedQuery = await _redeemedVouchersCollection
          .where('voucherId', isEqualTo: doc.id)
          .limit(1)
          .get();

      if (redeemedQuery.docs.isNotEmpty) {
        // Voucher has been redeemed
        final redeemedData =
            redeemedQuery.docs.first.data() as Map<String, dynamic>;
        voucherData['isUsed'] = true;
        voucherData['usedBy'] = redeemedData['userId'];

        // Convert redemption timestamp
        final redeemedAt = redeemedData['redeemedAt'];
        if (redeemedAt != null) {
          final timestamp = redeemedAt as dynamic;
          if (timestamp.toString().contains('Timestamp')) {
            voucherData['usedDate'] = timestamp.toDate().toIso8601String();
          } else {
            voucherData['usedDate'] = redeemedAt;
          }
        }
      }

      final voucher = Voucher.fromJson(voucherData);

      // Check if voucher is valid (not used and not expired)
      if (voucher.isValid) {
        return voucher;
      }

      // If voucher is used but not expired, still return it for exam data access
      if (!voucher.isExpired) {
        print(
          'Debug: Voucher is used but not expired, returning for exam data access',
        );
        return voucher;
      }

      return null;
    } catch (e) {
      print('Error validating cloud voucher: $e');
      return null;
    }
  }

  /// Redeem a voucher and mark it as used
  static Future<bool> redeemCloudVoucher(String code, String userId) async {
    try {
      // First validate the voucher
      final voucher = await validateCloudVoucher(code);
      if (voucher == null) {
        return false; // Invalid or already used voucher
      }

      // Mark voucher as redeemed
      await _redeemedVouchersCollection.add({
        'voucherId': voucher.id,
        'voucherCode': voucher.code,
        'userId': userId,
        'redeemedAt': FieldValue.serverTimestamp(),
        'examId': voucher.examId,
        'examData': voucher.examData,
      });

      return true;
    } catch (e) {
      print('Error redeeming cloud voucher: $e');
      return false;
    }
  }

  /// Get all vouchers from Firestore (for admin purposes)
  static Future<List<Voucher>> getAllCloudVouchers() async {
    try {
      final querySnapshot = await _vouchersCollection.get();
      final vouchers = <Voucher>[];

      for (final doc in querySnapshot.docs) {
        final voucherData = doc.data() as Map<String, dynamic>;

        // Convert Firestore Timestamps to ISO strings
        if (voucherData['createdDate'] != null) {
          final timestamp = voucherData['createdDate'] as dynamic;
          if (timestamp.toString().contains('Timestamp')) {
            voucherData['createdDate'] = timestamp.toDate().toIso8601String();
          }
        }

        if (voucherData['expiryDate'] != null) {
          final timestamp = voucherData['expiryDate'] as dynamic;
          if (timestamp.toString().contains('Timestamp')) {
            voucherData['expiryDate'] = timestamp.toDate().toIso8601String();
          }
        }

        // Check if voucher has been redeemed
        final redeemedQuery = await _redeemedVouchersCollection
            .where('voucherId', isEqualTo: doc.id)
            .limit(1)
            .get();

        if (redeemedQuery.docs.isNotEmpty) {
          final redeemedData =
              redeemedQuery.docs.first.data() as Map<String, dynamic>;
          voucherData['isUsed'] = true;
          voucherData['usedBy'] = redeemedData['userId'];

          // Convert redemption timestamp
          final redeemedAt = redeemedData['redeemedAt'];
          if (redeemedAt != null) {
            final timestamp = redeemedAt as dynamic;
            if (timestamp.toString().contains('Timestamp')) {
              voucherData['usedDate'] = timestamp.toDate().toIso8601String();
            } else {
              voucherData['usedDate'] = redeemedAt;
            }
          }
        }

        vouchers.add(Voucher.fromJson(voucherData));
      }

      return vouchers;
    } catch (e) {
      print('Error getting cloud vouchers: $e');
      return [];
    }
  }

  /// Delete a voucher from Firestore
  static Future<bool> deleteCloudVoucher(String voucherId) async {
    try {
      await _vouchersCollection.doc(voucherId).delete();

      // Also delete associated redemption records
      final redeemedQuery = await _redeemedVouchersCollection
          .where('voucherId', isEqualTo: voucherId)
          .get();

      for (final doc in redeemedQuery.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      print('Error deleting cloud voucher: $e');
      return false;
    }
  }

  /// Update a voucher in Firestore
  static Future<bool> updateCloudVoucher(Voucher voucher) async {
    try {
      await _vouchersCollection.doc(voucher.id).update(voucher.toJson());
      return true;
    } catch (e) {
      print('Error updating cloud voucher: $e');
      return false;
    }
  }

  /// Get voucher statistics
  static Future<Map<String, dynamic>> getVoucherStats() async {
    try {
      final totalVouchers = await _vouchersCollection.count().get();
      final totalRedeemed = await _redeemedVouchersCollection.count().get();

      return {
        'totalVouchers': (totalVouchers.count ?? 0),
        'totalRedeemed': (totalRedeemed.count ?? 0),
        'activeVouchers':
            (totalVouchers.count ?? 0) - (totalRedeemed.count ?? 0),
      };
    } catch (e) {
      print('Error getting voucher stats: $e');
      return {'totalVouchers': 0, 'totalRedeemed': 0, 'activeVouchers': 0};
    }
  }

  /// Check if a user has redeemed a specific voucher
  static Future<bool> hasUserRedeemedVoucher(
    String voucherId,
    String userId,
  ) async {
    try {
      final query = await _redeemedVouchersCollection
          .where('voucherId', isEqualTo: voucherId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking user voucher redemption: $e');
      return false;
    }
  }

  /// Get all vouchers redeemed by a specific user
  static Future<List<Map<String, dynamic>>> getUserRedeemedVouchers(
    String userId,
  ) async {
    try {
      final query = await _redeemedVouchersCollection
          .where('userId', isEqualTo: userId)
          .get();

      return query.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting user redeemed vouchers: $e');
      return [];
    }
  }

  /// Get voucher data for exam unlocking (ignores usage status)
  static Future<Voucher?> getVoucherForUnlock(String code) async {
    try {
      // Query for the voucher by code
      final querySnapshot = await _vouchersCollection
          .where('code', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null; // Voucher not found
      }

      final doc = querySnapshot.docs.first;
      final voucherData = doc.data() as Map<String, dynamic>;

      print(
        'Debug: getVoucherForUnlock - Raw voucher data: ${voucherData.keys.toList()}',
      );
      print(
        'Debug: getVoucherForUnlock - examData present: ${voucherData['examData'] != null}',
      );

      // Convert Firestore Timestamps to ISO strings
      if (voucherData['createdDate'] != null) {
        final timestamp = voucherData['createdDate'] as dynamic;
        if (timestamp.toString().contains('Timestamp')) {
          voucherData['createdDate'] = timestamp.toDate().toIso8601String();
        }
      }

      if (voucherData['expiryDate'] != null) {
        final timestamp = voucherData['expiryDate'] as dynamic;
        if (timestamp.toString().contains('Timestamp')) {
          voucherData['expiryDate'] = timestamp.toDate().toIso8601String();
        }
      }

      // Check if voucher has been redeemed
      final redeemedQuery = await _redeemedVouchersCollection
          .where('voucherId', isEqualTo: doc.id)
          .limit(1)
          .get();

      if (redeemedQuery.docs.isNotEmpty) {
        // Voucher has been redeemed
        final redeemedData =
            redeemedQuery.docs.first.data() as Map<String, dynamic>;
        voucherData['isUsed'] = true;
        voucherData['usedBy'] = redeemedData['userId'];

        // Convert redemption timestamp
        final redeemedAt = redeemedData['redeemedAt'];
        if (redeemedAt != null) {
          final timestamp = redeemedAt as dynamic;
          if (timestamp.toString().contains('Timestamp')) {
            voucherData['usedDate'] = timestamp.toDate().toIso8601String();
          } else {
            voucherData['usedDate'] = redeemedAt;
          }
        }
      }

      final voucher = Voucher.fromJson(voucherData);

      // Return voucher if not expired (regardless of usage status)
      if (!voucher.isExpired) {
        print('Debug: getVoucherForUnlock - Returning voucher with exam data');
        return voucher;
      }

      return null;
    } catch (e) {
      print('Error getting voucher for unlock: $e');
      return null;
    }
  }

  /// Generate a unique voucher code
  static String _generateVoucherCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure(); // Use secure random for better randomness
    final code = StringBuffer();

    // Generate 8-character code with better formatting
    for (int i = 0; i < 8; i++) {
      // Add a dash after 4 characters for better readability
      if (i == 4) {
        code.write('-');
      }
      code.write(chars[random.nextInt(chars.length)]);
    }

    return code.toString();
  }
}
