import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'notification_service.dart';
import 'package:intl/intl.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mevcut Firebase Auth kullanıcısı
  User? get currentFirebaseUser => _auth.currentUser;
  
  /// Bonus adım formatlama (örn: 200000 -> "200.000")
  String _formatBonusSteps(int steps) {
    return NumberFormat.decimalPattern('tr').format(steps);
  }

  /// Benzersiz 6 karakterli kişisel referral kodu oluştur
  Future<String> _generateUniquePersonalReferralCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Karışıklık yaratabilecek 0,O,1,I hariç
    final random = Random();
    
    while (true) {
      final code = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
      
      // Bu kodun kullanılıp kullanılmadığını kontrol et
      final existing = await _firestore
          .collection('users')
          .where('personal_referral_code', isEqualTo: code)
          .limit(1)
          .get();
      
      if (existing.docs.isEmpty) {
        return code;
      }
    }
  }

  /// Eski kullanıcılar için kişisel referral kodu oluştur ve kaydet
  Future<String?> ensurePersonalReferralCode(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) return null;
      
      final userData = userDoc.data();
      final existingCode = userData?['personal_referral_code'];
      
      // Zaten kod varsa, onu döndür
      if (existingCode != null && existingCode.toString().isNotEmpty) {
        return existingCode;
      }
      
      // Yoksa yeni kod oluştur ve kaydet
      final newCode = await _generateUniquePersonalReferralCode();
      
      await _firestore.collection('users').doc(userId).update({
        'personal_referral_code': newCode,
        'referral_count': userData?['referral_count'] ?? 0,
      });
      
      return newCode;
    } catch (e) {
      print('Error ensuring personal referral code: $e');
      return null;
    }
  }

  /// Kayıt Ol (Referral Code ile Otomatik Takım Ekleme + Kişisel Referral)
  /// 
  /// İş Mantığı:
  /// 1. Firebase Auth'ta kullanıcı oluştur
  /// 2. Takım referral code varsa, takımı bul
  /// 3. Kişisel referral code varsa, davet edeni bul
  /// 4. User koleksiyonunda yeni belge oluştur
  /// 5. Referral code varsa, joinTeamByReferral'ı çağır
  /// 6. Kişisel referral varsa, her iki tarafa 100.000 carry-over adım ekle
  Future<Map<String, dynamic>> signUpWithReferral({
    required String fullName,
    required String email,
    required String password,
    String? referralCode, // Takım referral kodu
    String? personalReferralCode, // Kişisel referral kodu
  }) async {
    try {
      // 1. Firebase Auth'ta kullanıcı oluştur
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;

      // 2. Takım referral code varsa takımı bul
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

      // 3. Kişisel referral code varsa davet edeni bul
      String? referrerUserId;
      if (personalReferralCode != null && personalReferralCode.isNotEmpty) {
        final referrerQuery = await _firestore
            .collection('users')
            .where('personal_referral_code', isEqualTo: personalReferralCode.toUpperCase())
            .limit(1)
            .get();

        if (referrerQuery.docs.isNotEmpty) {
          referrerUserId = referrerQuery.docs.first.id;
        }
      }

      // 4. Yeni kullanıcı için benzersiz kişisel referral kodu oluştur
      final newUserReferralCode = await _generateUniquePersonalReferralCode();

      // 5. User koleksiyonunda yeni belge oluştur
      final maskedName = UserModel.maskName(fullName);
      final userData = {
        'full_name': fullName,
        'full_name_lowercase': fullName.toLowerCase(),
        'masked_name': maskedName,
        'nickname': null,
        'email': email,
        'profile_image_url': null,
        'wallet_balance_hope': 0.0,
        'current_team_id': targetTeamId,
        'theme_preference': 'light',
        'created_at': Timestamp.now(),
        'last_step_sync_time': null,
        'device_tokens': [],
        // Kişisel Referral Alanları
        'personal_referral_code': newUserReferralCode,
        'referred_by': referrerUserId,
        'referral_count': 0,
      };

      await _firestore.collection('users').doc(userId).set(userData);

      // 6. Takım referral code varsa, team_members'a ekle
      if (targetTeamId != null) {
        final teamDoc = _firestore.collection('teams').doc(targetTeamId);
        
        await teamDoc.collection('team_members').doc(userId).set({
          'team_id': targetTeamId,
          'user_id': userId,
          'member_status': 'active',
          'join_date': Timestamp.now(),
          'member_total_hope': 0.0,
          'member_daily_steps': 0,
        });

        final teamData = (await teamDoc.get()).data();
        final memberIds = List<String>.from(teamData?['member_ids'] ?? []);
        memberIds.add(userId);

        await teamDoc.update({
          'members_count': FieldValue.increment(1),
          'member_ids': memberIds,
        });
        
        // 🎁 TAKIM REFERRAL BONUSU: Hem takıma hem kullanıcıya 100.000 adım
        const teamReferralBonus = 100000;
        
        // Takıma bonus ekle
        await teamDoc.update({
          'team_bonus_steps': FieldValue.increment(teamReferralBonus),
        });
        
        // Kullanıcıya bonus ekle
        await _firestore.collection('users').doc(userId).update({
          'referral_bonus_steps': FieldValue.increment(teamReferralBonus),
        });
        
        // Activity log ekle - Takım referral bonusu
        await _firestore.collection('activity_logs').add({
          'user_id': userId,
          'team_id': targetTeamId,
          'activity_type': 'team_referral_bonus',
          'bonus_steps': teamReferralBonus,
          'created_at': Timestamp.now(),
        });
      }

      // 7. Kişisel referral varsa, her iki tarafa 100.000 carry-over adım ekle
      if (referrerUserId != null) {
        final referralBonus = 100000; // 100.000 adım
        final today = DateTime.now();
        final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

        // Davet eden kullanıcıya bonus ekle
        await _addReferralBonusSteps(referrerUserId, referralBonus, dateStr, userId, fullName);
        
        // Davet edilen (yeni kullanıcı) kullanıcıya bonus ekle
        await _addReferralBonusSteps(userId, referralBonus, dateStr, referrerUserId, null);

        // Davet edenin referral_count'unu artır
        await _firestore.collection('users').doc(referrerUserId).update({
          'referral_count': FieldValue.increment(1),
        });
      }

      String message = 'Başarıyla kayıt oldunuz!';
      int totalBonusSteps = 0;
      
      // Takım bonusu varsa
      if (targetTeamId != null) {
        totalBonusSteps += 100000; // Takım referral bonusu
      }
      
      // Kişisel referral bonusu varsa
      if (referrerUserId != null) {
        totalBonusSteps += 100000; // Kişisel referral bonusu
      }
      
      if (targetTeamId != null && referrerUserId != null) {
        message = 'Başarıyla kayıt oldunuz, takıma katıldınız ve ${_formatBonusSteps(totalBonusSteps)} bonus adım kazandınız!';
      } else if (targetTeamId != null) {
        message = 'Başarıyla kayıt oldunuz, takıma katıldınız ve 100.000 bonus adım kazandınız!';
      } else if (referrerUserId != null) {
        message = 'Başarıyla kayıt oldunuz ve 100.000 bonus adım kazandınız!';
      }

      return {
        'success': true,
        'userId': userId,
        'teamId': targetTeamId,
        'referrerUserId': referrerUserId,
        'personalReferralCode': newUserReferralCode,
        'message': message,
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

  /// Referral bonus adımlarını kullanıcıya ekle (Süresiz - users koleksiyonunda)
  Future<void> _addReferralBonusSteps(String userId, int bonusSteps, String dateStr, String otherUserId, String? otherUserName) async {
    // Kullanıcı dökümanına süresiz bonus ekle
    await _firestore.collection('users').doc(userId).update({
      'referral_bonus_steps': FieldValue.increment(bonusSteps),
    });

    // Activity log ekle
    await _firestore.collection('users').doc(userId).collection('activity_log').add({
      'type': 'referral_bonus',
      'timestamp': Timestamp.now(),
      'bonus_steps': bonusSteps,
      'other_user_id': otherUserId,
      'other_user_name': otherUserName,
    });
  }

  /// Giriş Yap
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Günlük aktif kullanıcı için last_login_at güncelle
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).update({
          'last_login_at': FieldValue.serverTimestamp(),
        });
        
        // FCM token'ı güncelle
        await NotificationService().updateFcmTokenAfterLogin();
      }

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'error': e.code,
      };
    } catch (e) {
      // Firebase Auth hatalarını yakala
      if (e.toString().contains('user-not-found')) {
        return {
          'success': false,
          'error': 'user-not-found',
        };
      } else if (e.toString().contains('wrong-password')) {
        return {
          'success': false,
          'error': 'wrong-password',
        };
      } else if (e.toString().contains('invalid-credential')) {
        return {
          'success': false,
          'error': 'user-not-found',
        };
      }
      return {
        'success': false,
        'error': e.toString(),
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

  /// Google/Apple ile kayıt sonrası referral kodlarını işle
  /// Bu metod, social login sonrası referral dialog'dan çağrılır
  Future<Map<String, dynamic>> processReferralCodesForSocialLogin({
    required String userId,
    String? teamReferralCode,
    String? personalReferralCode,
  }) async {
    try {
      String? targetTeamId;
      String? referrerUserId;
      int totalBonusSteps = 0;

      // 1. Takım referral kodu varsa takımı bul ve kullanıcıyı ekle
      if (teamReferralCode != null && teamReferralCode.isNotEmpty) {
        final teamQuery = await _firestore
            .collection('teams')
            .where('referral_code', isEqualTo: teamReferralCode.toUpperCase())
            .limit(1)
            .get();

        if (teamQuery.docs.isNotEmpty) {
          final teamDoc = teamQuery.docs.first;
          targetTeamId = teamDoc.id;

          // Kullanıcıyı takıma ekle
          await _firestore.collection('users').doc(userId).update({
            'current_team_id': targetTeamId,
          });

          // Team member olarak ekle
          final userDoc = await _firestore.collection('users').doc(userId).get();
          final userData = userDoc.data();
          
          await _firestore
              .collection('teams')
              .doc(targetTeamId)
              .collection('team_members')
              .doc(userId)
              .set({
            'user_id': userId,
            'display_name': userData?['masked_name'] ?? userData?['full_name'] ?? 'Kullanıcı',
            'joined_at': Timestamp.now(),
            'role': 'member',
            'member_total_hope': 0.0,
            'member_daily_steps': 0,
          });

          final teamData = teamDoc.data();
          final memberIds = List<String>.from(teamData['member_ids'] ?? []);
          memberIds.add(userId);

          await _firestore.collection('teams').doc(targetTeamId).update({
            'members_count': FieldValue.increment(1),
            'member_ids': memberIds,
          });

          // Takım referral bonusu
          const teamReferralBonus = 100000;
          await _firestore.collection('teams').doc(targetTeamId).update({
            'team_bonus_steps': FieldValue.increment(teamReferralBonus),
          });
          await _firestore.collection('users').doc(userId).update({
            'referral_bonus_steps': FieldValue.increment(teamReferralBonus),
          });
          
          totalBonusSteps += teamReferralBonus;
        }
      }

      // 2. Kişisel referral kodu varsa davet edeni bul
      if (personalReferralCode != null && personalReferralCode.isNotEmpty) {
        final referrerQuery = await _firestore
            .collection('users')
            .where('personal_referral_code', isEqualTo: personalReferralCode.toUpperCase())
            .limit(1)
            .get();

        if (referrerQuery.docs.isNotEmpty) {
          referrerUserId = referrerQuery.docs.first.id;
          final referralBonus = 100000;
          final today = DateTime.now();
          final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

          // Her iki tarafa bonus ekle
          await _addReferralBonusSteps(referrerUserId, referralBonus, dateStr, userId, null);
          await _addReferralBonusSteps(userId, referralBonus, dateStr, referrerUserId, null);

          // Davet edenin referral_count'unu artır
          await _firestore.collection('users').doc(referrerUserId).update({
            'referral_count': FieldValue.increment(1),
          });

          // Davet edilenin referred_by alanını güncelle
          await _firestore.collection('users').doc(userId).update({
            'referred_by': referrerUserId,
          });

          totalBonusSteps += referralBonus;
        }
      }

      String message = '';
      if (targetTeamId != null && referrerUserId != null) {
        message = 'Takıma katıldınız ve ${_formatBonusSteps(totalBonusSteps)} bonus adım kazandınız!';
      } else if (targetTeamId != null) {
        message = 'Takıma katıldınız ve 100.000 bonus adım kazandınız!';
      } else if (referrerUserId != null) {
        message = '100.000 bonus adım kazandınız!';
      }

      return {
        'success': true,
        'teamId': targetTeamId,
        'referrerUserId': referrerUserId,
        'totalBonusSteps': totalBonusSteps,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Firebase Hata Kodlarını Döndür (çeviri language_provider'da yapılacak)
  String _getFirebaseErrorMessage(String code) {
    // Hata kodunu döndür, çeviri UI'da yapılacak
    return code;
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
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Google ile oturum aç
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        return {
          'success': false,
          'error': 'GOOGLE_SIGN_IN_CANCELLED',
        };
      }

      // Google kimlik bilgilerini al
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase credential oluştur
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase ile giriş yap
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
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
        
        // Kişisel referral kodu oluştur
        final personalReferralCode = await _generateUniquePersonalReferralCode();

        await _firestore.collection('users').doc(user.uid).set({
          'full_name': fullName,
          'full_name_lowercase': fullName.toLowerCase(), // Arama için lowercase
          'masked_name': maskedName,
          'nickname': null,
          'email': user.email,
          'profile_image_url': user.photoURL,
          'wallet_balance_hope': 0.0,
          'current_team_id': null,
          'theme_preference': 'light',
          'created_at': Timestamp.now(),
          'last_login_at': Timestamp.now(), // Günlük aktif için
          'last_step_sync_time': null,
          'device_tokens': [],
          'auth_provider': 'google',
          'personal_referral_code': personalReferralCode,
          'referral_count': 0,
        });
        
        // FCM token'ı güncelle
        await NotificationService().updateFcmTokenAfterLogin();

        return {
          'success': true,
          'isNewUser': true,
          'message': 'Google ile başarıyla kayıt oldunuz!',
        };
      }

      // Mevcut kullanıcı - last_login_at güncelle
      await _firestore.collection('users').doc(user.uid).update({
        'last_login_at': FieldValue.serverTimestamp(),
      });
      
      // FCM token'ı güncelle
      await NotificationService().updateFcmTokenAfterLogin();

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
        
        // Kişisel referral kodu oluştur
        final personalReferralCode = await _generateUniquePersonalReferralCode();

        await _firestore.collection('users').doc(user.uid).set({
          'full_name': fullName,
          'full_name_lowercase': fullName.toLowerCase(), // Arama için lowercase
          'masked_name': maskedName,
          'nickname': null,
          'email': user.email,
          'profile_image_url': user.photoURL,
          'wallet_balance_hope': 0.0,
          'current_team_id': null,
          'theme_preference': 'light',
          'created_at': Timestamp.now(),
          'last_login_at': Timestamp.now(), // Günlük aktif için
          'last_step_sync_time': null,
          'device_tokens': [],
          'auth_provider': 'apple',
          'personal_referral_code': personalReferralCode,
          'referral_count': 0,
        });
        
        // FCM token'ı güncelle
        await NotificationService().updateFcmTokenAfterLogin();

        return {
          'success': true,
          'isNewUser': true,
          'message': 'Apple ile başarıyla kayıt oldunuz!',
        };
      }

      // Mevcut kullanıcı - last_login_at güncelle
      await _firestore.collection('users').doc(user.uid).update({
        'last_login_at': FieldValue.serverTimestamp(),
      });
      
      // FCM token'ı güncelle
      await NotificationService().updateFcmTokenAfterLogin();

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

  /// Google/Apple kullanıcısına e-posta/şifre ile giriş ekleme
  /// Bu, sosyal login kullanıcılarının e-posta/şifre ile de giriş yapabilmesini sağlar
  Future<Map<String, dynamic>> createPasswordForSocialUser({
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'Kullanıcı oturumu bulunamadı',
        };
      }

      final email = user.email;
      if (email == null || email.isEmpty) {
        return {
          'success': false,
          'error': 'E-posta adresi bulunamadı',
        };
      }

      // E-posta/şifre credential oluştur ve mevcut hesaba bağla
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.linkWithCredential(credential);

      // Firestore'da auth_provider'a 'email' ekle
      await _firestore.collection('users').doc(user.uid).update({
        'has_password': true,
        'auth_provider': 'email', // Artık e-posta ile de giriş yapabilir
      });

      return {
        'success': true,
        'message': 'Şifre başarıyla oluşturuldu! Artık e-posta ve şifre ile de giriş yapabilirsiniz.',
      };
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        return {
          'success': false,
          'error': 'Bu hesapta zaten bir şifre tanımlı.',
        };
      } else if (e.code == 'credential-already-in-use') {
        return {
          'success': false,
          'error': 'Bu e-posta başka bir hesapla ilişkili.',
        };
      } else if (e.code == 'weak-password') {
        return {
          'success': false,
          'error': 'Şifre çok zayıf. En az 6 karakter olmalı.',
        };
      }
      return {
        'success': false,
        'error': _getFirebaseErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Şifre oluşturma hatası: $e',
      };
    }
  }

  /// Kullanıcının şifresi var mı kontrol et
  Future<bool> hasEmailPasswordProvider() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    return user.providerData.any((provider) => provider.providerId == 'password');
  }
}
