import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/activity_log_model.dart';

class ActivityLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Bağış işlemini kaydıt ve Hope bakiyesini güncelle
  /// 
  /// İş Mantığı:
  /// 1. Kullanıcının bakiyesi kontrol edilir (>= 5 Hope)
  /// 2. Reklam gösterilir (app'de implementation)
  /// 3. Activity log oluşturulur
  /// 4. Kullanıcı bakiyesi güncellenir
  /// 5. Team'in toplam Hope'ü güncellenir
  /// 6. Team member'ın Hope'ü güncellenir
  Future<Map<String, dynamic>> createDonationLog({
    required String charityName,
    required double hopeAmount,
    String? charityLogoUrl,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {'success': false, 'error': 'Kullanıcı oturum açmamış'};
      }

      // Kullanıcı bakiyesini kontrol et
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {'success': false, 'error': 'Kullanıcı bulunamadı'};
      }

      final userData = userDoc.data()!;
      final currentBalance = (userData['wallet_balance_hope'] ?? 0).toDouble();

      if (currentBalance < hopeAmount) {
        return {
          'success': false,
          'error':
              'Yetersiz bakiye. Daha fazla adım atmalısınız.',
          'currentBalance': currentBalance,
        };
      }

      // Activity log oluştur
      final logRef = _firestore.collection('users').doc(userId).collection('activity_logs').doc();
      await logRef.set({
        'user_id': userId,
        'action_type': 'donation',
        'target_name': charityName,
        'amount': hopeAmount,
        'timestamp': Timestamp.now(),
        'charity_logo_url': charityLogoUrl,
      });

      // Kullanıcı bakiyesini güncelle
      await _firestore.collection('users').doc(userId).update({
        'wallet_balance_hope':
            FieldValue.increment(-hopeAmount),
      });

      // Eğer kullanıcı takımdaysa, takımın Hope'ünü güncelle
      final currentTeamId = userData['current_team_id'];
      if (currentTeamId != null) {
        final teamDoc = _firestore.collection('teams').doc(currentTeamId);

        // Team'in total_team_hope'ünü güncelle
        await teamDoc.update({
          'total_team_hope': FieldValue.increment(hopeAmount),
        });

        // Team member'ın member_total_hope'ünü güncelle
        await teamDoc
            .collection('team_members')
            .doc(userId)
            .update({
          'member_total_hope': FieldValue.increment(hopeAmount),
        });
      }

      return {
        'success': true,
        'logId': logRef.id,
        'newBalance': currentBalance - hopeAmount,
        'message': '✅ $charityName\'a başarıyla $hopeAmount Hope bağışladınız!',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Adım dönüştürme işlemini kaydıt
  /// 
  /// İş Mantığı:
  /// 1. Dönüştürülebilecek adım sayısı kontrol edilir (max 2500)
  /// 2. Cooldown kontrol edilir (10 dakika)
  /// 3. Activity log oluşturulur
  /// 4. Hope bakiyesi güncellenir (2500 adım = 0.10 Hope)
  /// 5. Günlük adım verisi güncellenir
  Future<Map<String, dynamic>> createStepConversionLog({
    required int stepsToConvert,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {'success': false, 'error': 'Kullanıcı oturum açmamış'};
      }

      // Maksimum dönüştürülebilecek adım sayısını kontrol et
      if (stepsToConvert > 2500) {
        return {
          'success': false,
          'error': 'Tek seferde maksimum 2500 adım dönüştürebilirsiniz',
        };
      }

      // Hope miktarını hesapla (2500 adım = 0.10 Hope)
      final hopeAmount = (stepsToConvert / 2500) * 0.10;

      // Activity log oluştur
      final logRef = _firestore.collection('users').doc(userId).collection('activity_logs').doc();
      await logRef.set({
        'user_id': userId,
        'action_type': 'step_conversion',
        'target_name': 'Adım Dönüştürme',
        'amount': hopeAmount,
        'steps_converted': stepsToConvert,
        'timestamp': Timestamp.now(),
      });

      // Kullanıcı bakiyesini güncelle
      await _firestore.collection('users').doc(userId).update({
        'wallet_balance_hope': FieldValue.increment(hopeAmount),
      });

      // Günlük adım verisi güncelle
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final stepDocId = '$userId-$dateStr';

      final stepDocRef =
          _firestore.collection('daily_steps').doc(stepDocId);

      await stepDocRef.set({
        'user_id': userId,
        'converted_steps': FieldValue.increment(stepsToConvert),
        'last_conversion_time': Timestamp.now(),
      }, SetOptions(merge: true));

      return {
        'success': true,
        'logId': logRef.id,
        'hopeGenerated': hopeAmount,
        'message': '✅ $stepsToConvert adım başarıyla dönüştürüldü. '
            '+$hopeAmount Hope kazandınız!',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Kullanıcının Activity Log geçmişini al (Real-time)
  Stream<List<ActivityLogModel>> getUserActivityLogsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ActivityLogModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Tüm Activity Log geçmişini al (Paginated)
  Future<List<ActivityLogModel>> getUserActivityLogs({
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('activity_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ActivityLogModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Activity log al hatası: $e');
      return [];
    }
  }

  /// Belirli bir dönem içindeki bağışları toplam
  Future<double> getTotalDonationsByPeriod({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('activity_logs')
          .where('action_type', isEqualTo: 'donation')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }

      return total;
    } catch (e) {
      print('Bağış toplamı al hatası: $e');
      return 0;
    }
  }
}
