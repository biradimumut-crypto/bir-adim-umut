import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Kayıt Ol (Referral Code ile Otomatik Takım Ekleme)
  /// 
  /// İş Mantığı:
  /// 1. Firebase Auth'ta kullanıcı oluştur
  /// 2. Referral code varsa, takımı bul
  /// 3. User koleksiyonunda yeni belge oluştur
  /// 4. Referral code varsa, joinTeamByReferral'ı çağır
  Future<Map<String, dynamic>> signUpWithReferral({
    required String fullName,
    required String email,
    required String password,
    String? referralCode,
  }) async {
    try {
      // 1. Firebase Auth'ta kullanıcı oluştur
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;

      // 2. Referral code varsa takımı bul
      String? targetTeamId;
      if (referralCode != null && referralCode.isNotEmpty) {
        final teamQuery = await _firestore
            .collection('teams')
            .where('referral_code', isEqualTo: referralCode.toUpperCase())
            .limit(1)
            .get();

        if (teamQuery.docs.isNotEmpty) {
          targetTeamId = teamQuery.docs[0].id;
        }
      }

      // 3. User koleksiyonunda yeni belge oluştur
      final maskedName = UserModel.maskName(fullName);
      final userData = {
        'full_name': fullName,
        'masked_name': maskedName,
        'nickname': null,
        'email': email,
        'profile_image_url': null,
        'wallet_balance_hope': 0.0,
        'current_team_id': targetTeamId, // Referral code varsa team ekle
        'theme_preference': 'light',
        'created_at': Timestamp.now(),
        'last_step_sync_time': null,
        'device_tokens': [], // Firebase Messaging için
      };

      await _firestore.collection('users').doc(userId).set(userData);

      // 4. Referral code varsa, team_members'a ekle
      if (targetTeamId != null) {
        final teamDoc = _firestore.collection('teams').doc(targetTeamId);
        
        // team_members'a ekle
        await teamDoc.collection('team_members').doc(userId).set({
          'team_id': targetTeamId,
          'user_id': userId,
          'member_status': 'active',
          'join_date': Timestamp.now(),
          'member_total_hope': 0.0,
          'member_daily_steps': 0,
        });

        // Team'in members_count ve member_ids'i güncelle
        final teamData = (await teamDoc.get()).data();
        final memberIds = List<String>.from(teamData?['member_ids'] ?? []);
        memberIds.add(userId);

        await teamDoc.update({
          'members_count': FieldValue.increment(1),
          'member_ids': memberIds,
        });
      }

      return {
        'success': true,
        'userId': userId,
        'teamId': targetTeamId,
        'message': targetTeamId != null
            ? 'Başarıyla kayıt oldunuz ve takıma katıldınız!'
            : 'Başarıyla kayıt oldunuz!',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'error': _getFirebaseErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Giriş Yap
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'error': _getFirebaseErrorMessage(e.code),
      };
    }
  }

  /// Çıkış Yap
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Şifre Sıfırla
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'error': _getFirebaseErrorMessage(e.code),
      };
    }
  }

  /// Mevcut Kullanıcıyı Al
  Future<UserModel?> getCurrentUser() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;

      return UserModel.fromFirestore(doc);
    } catch (e) {
      print('Mevcut kullanıcı al hatası: $e');
      return null;
    }
  }

  /// Firebase Hata Mesajlarını Türkçeye Çevir
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      case 'email-already-in-use':
        return 'Bu e-posta zaten kullanılıyor.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-not-found':
        return 'Kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Şifre yanlış.';
      case 'account-exists-with-different-credential':
        return 'Bu e-posta başka bir hesapla kaydedilmiş.';
      default:
        return 'Hata: $code';
    }
  }

  /// Kullanıcı Oturum Açtı mı?
  Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  /// Mevcut Kullanıcı UID'sini Al
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Google ile Giriş/Kayıt
  /// Eğer kullanıcı daha önce kayıtlı değilse otomatik kayıt yapar
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Web için: signInWithPopup kullan
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      // Firebase ile Google girişi yap
      final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
      final user = userCredential.user;

      if (user == null) {
        return {
          'success': false,
          'error': 'Kullanıcı bilgisi alınamadı.',
        };
      }

      // Kullanıcı Firestore'da var mı kontrol et
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // Yeni kullanıcı - otomatik kayıt yap
        final fullName = user.displayName ?? 'Kullanıcı';
        final maskedName = UserModel.maskName(fullName);

        await _firestore.collection('users').doc(user.uid).set({
          'full_name': fullName,
          'masked_name': maskedName,
          'nickname': null,
          'email': user.email,
          'profile_image_url': user.photoURL,
          'wallet_balance_hope': 0.0,
          'current_team_id': null,
          'theme_preference': 'light',
          'created_at': Timestamp.now(),
          'last_step_sync_time': null,
          'device_tokens': [],
          'auth_provider': 'google',
        });

        return {
          'success': true,
          'isNewUser': true,
          'message': 'Google ile başarıyla kayıt oldunuz!',
        };
      }

      return {
        'success': true,
        'isNewUser': false,
        'message': 'Google ile giriş yapıldı!',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'error': _getFirebaseErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Google girişi sırasında hata: $e',
      };
    }
  }

  /// Apple ile Giriş/Kayıt
  /// Eğer kullanıcı daha önce kayıtlı değilse otomatik kayıt yapar
  Future<Map<String, dynamic>> signInWithApple() async {
    try {
      // Apple Sign In provider
      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      // Firebase ile Apple girişi yap
      final UserCredential userCredential = await _auth.signInWithProvider(appleProvider);
      final user = userCredential.user;

      if (user == null) {
        return {
          'success': false,
          'error': 'Kullanıcı bilgisi alınamadı.',
        };
      }

      // Kullanıcı Firestore'da var mı kontrol et
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // Yeni kullanıcı - otomatik kayıt yap
        final fullName = user.displayName ?? 'Apple Kullanıcısı';
        final maskedName = UserModel.maskName(fullName);

        await _firestore.collection('users').doc(user.uid).set({
          'full_name': fullName,
          'masked_name': maskedName,
          'nickname': null,
          'email': user.email,
          'profile_image_url': user.photoURL,
          'wallet_balance_hope': 0.0,
          'current_team_id': null,
          'theme_preference': 'light',
          'created_at': Timestamp.now(),
          'last_step_sync_time': null,
          'device_tokens': [],
          'auth_provider': 'apple',
        });

        return {
          'success': true,
          'isNewUser': true,
          'message': 'Apple ile başarıyla kayıt oldunuz!',
        };
      }

      return {
        'success': true,
        'isNewUser': false,
        'message': 'Apple ile giriş yapıldı!',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'error': _getFirebaseErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Apple girişi sırasında hata: $e',
      };
    }
  }
}
