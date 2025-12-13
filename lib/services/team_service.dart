import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/team_model.dart';
import '../models/team_member_model.dart';
import '../models/notification_model.dart';
import '../models/activity_log_model.dart';
import '../models/user_model.dart';

class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Takım Oluştur (Cloud Function çağırma)
  Future<Map<String, dynamic>> createTeam({
    required String teamName,
    String? logoUrl,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createTeam');
      final result = await callable.call({
        'teamName': teamName,
        'logoUrl': logoUrl,
      });

      return {
        'success': true,
        'teamId': result.data['teamId'],
        'referralCode': result.data['referralCode'],
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message,
      };
    }
  }

  /// Referral Code ile Takıma Katıl
  Future<Map<String, dynamic>> joinTeamByReferral(String referralCode) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('joinTeamByReferral');
      final result = await callable.call({
        'referralCode': referralCode.toUpperCase(),
      });

      return {
        'success': true,
        'teamId': result.data['teamId'],
        'teamName': result.data['teamName'],
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message,
      };
    }
  }

  /// Kullanıcıyı Takıma Davet Et
  Future<Map<String, dynamic>> inviteUserToTeam({
    required String targetUserNameOrNickname,
    required String teamId,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('inviteUserToTeam');
      final result = await callable.call({
        'targetUserNameOrNickname': targetUserNameOrNickname,
        'teamId': teamId,
      });

      return {
        'success': true,
        'notificationId': result.data['notificationId'],
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message,
      };
    }
  }

  /// Daveti Kabul Et
  Future<Map<String, dynamic>> acceptTeamInvite({
    required String notificationId,
    required String teamId,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('acceptTeamInvite');
      final result = await callable.call({
        'notificationId': notificationId,
        'teamId': teamId,
      });

      return {
        'success': true,
        'teamId': result.data['teamId'],
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message,
      };
    }
  }

  /// Daveti Reddet
  Future<Map<String, dynamic>> rejectTeamInvite(String notificationId) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('rejectTeamInvite');
      await callable.call({
        'notificationId': notificationId,
      });

      return {
        'success': true,
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message,
      };
    }
  }

  /// Takım Detayını Al
  Future<TeamModel?> getTeamById(String teamId) async {
    try {
      final doc = await _firestore.collection('teams').doc(teamId).get();
      if (!doc.exists) return null;
      return TeamModel.fromFirestore(doc);
    } catch (e) {
      print('Takım al hatası: $e');
      return null;
    }
  }

  /// Takım Üyelerini Al (Real-time)
  Stream<List<TeamMemberModel>> getTeamMembersStream(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('team_members')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TeamMemberModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Takım Üyelerinin Detaylı Bilgisini Al (Kullanıcı + Team Member)
  Future<List<Map<String, dynamic>>> getTeamMembersWithDetails(
      String teamId) async {
    try {
      final membersSnapshot = await _firestore
          .collection('teams')
          .doc(teamId)
          .collection('team_members')
          .get();

      List<Map<String, dynamic>> membersDetail = [];

      for (var memberDoc in membersSnapshot.docs) {
        final memberData = memberDoc.data();
        final userId = memberData['user_id'];

        // Kullanıcı bilgisini al
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          membersDetail.add({
            'userId': userId,
            'userName': userData?['full_name'] ?? 'Bilinmiyor',
            'maskedName': userData?['masked_name'],
            'profileImageUrl': userData?['profile_image_url'],
            'dailySteps': memberData['member_daily_steps'] ?? 0,
            'totalHope': memberData['member_total_hope'] ?? 0,
            'joinDate': memberData['join_date'],
          });
        }
      }

      return membersDetail;
    } catch (e) {
      print('Takım üyeleri detay al hatası: $e');
      return [];
    }
  }

  /// Tüm Takımları Sırala (Toplam Hope'ye göre)
  Future<List<TeamModel>> getAllTeamsLeaderboard() async {
    try {
      final snapshot = await _firestore
          .collection('teams')
          .orderBy('total_team_hope', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TeamModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Takım sıralaması al hatası: $e');
      return [];
    }
  }

  /// Takımdan Ayrıl
  Future<Map<String, dynamic>> leaveTeam(String teamId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {'success': false, 'error': 'Kullanıcı oturum açmamış'};
      }

      final teamDoc = _firestore.collection('teams').doc(teamId);

      // team_members'dan sil
      await teamDoc.collection('team_members').doc(userId).delete();

      // User'ın current_team_id'sini temizle
      await _firestore.collection('users').doc(userId).update({
        'current_team_id': null,
      });

      // Team'in members_count'ını azalt
      await teamDoc.update({
        'members_count': FieldValue.increment(-1),
      });

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
