import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String? maskedName; // İsim maskesi için
  final String? nickname;
  final String email;
  final String? profileImageUrl;
  final double walletBalanceHope;
  final String? currentTeamId; // Kullanıcının katıldığı takım
  final String themePreference; // dark/light
  final DateTime createdAt;
  final DateTime? lastStepSyncTime;

  UserModel({
    required this.uid,
    required this.fullName,
    this.maskedName,
    this.nickname,
    required this.email,
    this.profileImageUrl,
    required this.walletBalanceHope,
    this.currentTeamId,
    required this.themePreference,
    required this.createdAt,
    this.lastStepSyncTime,
  });

  /// Firestore'dan UserModel'e dönüştür
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel(
      uid: doc.id,
      fullName: data['full_name'] ?? '',
      maskedName: data['masked_name'],
      nickname: data['nickname'],
      email: data['email'] ?? '',
      profileImageUrl: data['profile_image_url'],
      walletBalanceHope: (data['wallet_balance_hope'] ?? 0).toDouble(),
      currentTeamId: data['current_team_id'],
      themePreference: data['theme_preference'] ?? 'light',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastStepSyncTime: (data['last_step_sync_time'] as Timestamp?)?.toDate(),
    );
  }

  /// UserModel'den Firestore Map'e dönüştür
  Map<String, dynamic> toFirestore() {
    return {
      'full_name': fullName,
      'masked_name': maskedName,
      'nickname': nickname,
      'email': email,
      'profile_image_url': profileImageUrl,
      'wallet_balance_hope': walletBalanceHope,
      'current_team_id': currentTeamId,
      'theme_preference': themePreference,
      'created_at': Timestamp.fromDate(createdAt),
      'last_step_sync_time': lastStepSyncTime != null 
          ? Timestamp.fromDate(lastStepSyncTime!) 
          : null,
    };
  }

  /// Kopya oluştur (güncelleme için)
  UserModel copyWith({
    String? uid,
    String? fullName,
    String? maskedName,
    String? nickname,
    String? email,
    String? profileImageUrl,
    double? walletBalanceHope,
    String? currentTeamId,
    String? themePreference,
    DateTime? createdAt,
    DateTime? lastStepSyncTime,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      maskedName: maskedName ?? this.maskedName,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      walletBalanceHope: walletBalanceHope ?? this.walletBalanceHope,
      currentTeamId: currentTeamId ?? this.currentTeamId,
      themePreference: themePreference ?? this.themePreference,
      createdAt: createdAt ?? this.createdAt,
      lastStepSyncTime: lastStepSyncTime ?? this.lastStepSyncTime,
    );
  }

  /// İsim maskeleme (sıralamada gizlilik için)
  static String maskName(String fullName) {
    if (fullName.isEmpty) return fullName;
    final parts = fullName.split(' ');
    if (parts.length < 2) {
      return parts[0][0] + '*' * (parts[0].length - 1);
    }
    return parts[0][0] + '*' * (parts[0].length - 1) + ' ' + parts[1];
  }
}
