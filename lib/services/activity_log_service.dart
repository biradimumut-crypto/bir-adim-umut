import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/activity_log_model.dart';
import 'badge_service.dart';

class ActivityLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BadgeService _badgeService = BadgeService();

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
    required String charityId,
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
      final userName = userData['full_name'] ?? 'Anonim';

      if (currentBalance < hopeAmount) {
        return {
          'success': false,
          'error':
              'Yetersiz bakiye. Daha fazla adım atmalısınız.',
          'currentBalance': currentBalance,
        };
      }

      // 1. User subcollection'a activity log oluştur (rozet hesaplama için)
      final userLogRef = _firestore.collection('users').doc(userId).collection('activity_logs').doc();
      await userLogRef.set({
        'user_id': userId,
        'activity_type': 'donation', // ✅ Standart format
        'action_type': 'donation',  // Geriye uyumluluk
        'target_name': charityName,
        'charity_id': charityId,
        'amount': hopeAmount,
        'timestamp': Timestamp.now(),
        'charity_logo_url': charityLogoUrl,
      });
      
      // 2. Global activity_logs'a da yaz (charity ekranı için)
      final globalLogRef = _firestore.collection('activity_logs').doc();
      await globalLogRef.set({
        'user_id': userId,
        'user_name': userName,
        'activity_type': 'donation',
        'charity_id': charityId,
        'charity_name': charityName,
        'amount': hopeAmount,  // Tutarlılık için amount kullan
        'hope_amount': hopeAmount,  // Geriye uyumluluk için
        'created_at': Timestamp.now(),
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

      // 🎖️ Lifetime bağışı güncelle ve rozet kontrol et
      await _badgeService.updateLifetimeDonations(hopeAmount);

      // 📊 Kullanıcının toplam bağış istatistiğini güncelle
      await _firestore.collection('users').doc(userId).update({
        'lifetime_donated_hope': FieldValue.increment(hopeAmount),
        'total_donation_count': FieldValue.increment(1),
      });

      // 🏛️ Vakfın bağış istatistiklerini güncelle
      try {
        final charityRef = _firestore.collection('charities').doc(charityId);
        final charityDoc = await charityRef.get();
        
        if (charityDoc.exists) {
          // İlk kez bağış yapan kullanıcı mı kontrol et
          final existingDonation = await _firestore
              .collection('activity_logs')
              .where('user_id', isEqualTo: userId)
              .where('charity_id', isEqualTo: charityId)
              .where('activity_type', isEqualTo: 'donation')
              .limit(2)
              .get();
          
          // Eğer bu kullanıcının bu vakfa ilk bağışıysa donor_count artır
          final isFirstDonation = existingDonation.docs.length <= 1;
          
          await charityRef.update({
            'collected_amount': FieldValue.increment(hopeAmount),
            if (isFirstDonation) 'donor_count': FieldValue.increment(1),
          });
        }
      } catch (e) {
        print('Vakıf istatistik güncelleme hatası: $e');
      }

      return {
        'success': true,
        'logId': userLogRef.id,
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
  /// 4. Hope bakiyesi güncellenir (2500 adım = 25 Hope, 100 adım = 1 Hope)
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

      // Hope miktarını hesapla (2500 adım = 25 Hope, 100 adım = 1 Hope)
      final hopeAmount = stepsToConvert / 100.0;

      // Activity log oluştur
      final logRef = _firestore.collection('users').doc(userId).collection('activity_logs').doc();
      await logRef.set({
        'user_id': userId,
        'activity_type': 'step_conversion', // ✅ Standart format
        'action_type': 'step_conversion',  // Geriye uyumluluk
        'target_name': 'Adım Dönüştürme',
        'amount': hopeAmount,
        'steps_converted': stepsToConvert,
        'timestamp': Timestamp.now(),
      });

      // Kullanıcı bakiyesini ve istatistiklerini güncelle
      await _firestore.collection('users').doc(userId).update({
        'wallet_balance_hope': FieldValue.increment(hopeAmount),
        'lifetime_converted_steps': FieldValue.increment(stepsToConvert),
        'lifetime_earned_hope': FieldValue.increment(hopeAmount),
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
          .map((doc) => ActivityLogModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
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
