import 'package:cloud_firestore/cloud_firestore.dart';

/// Bağış alıcısı türleri
enum RecipientType {
  charity,    // Vakıf
  community,  // Topluluk
  individual, // Birey
}

extension RecipientTypeExtension on RecipientType {
  String get displayName {
    switch (this) {
      case RecipientType.charity:
        return 'Vakıf';
      case RecipientType.community:
        return 'Topluluk';
      case RecipientType.individual:
        return 'Birey';
    }
  }

  String get value {
    switch (this) {
      case RecipientType.charity:
        return 'charity';
      case RecipientType.community:
        return 'community';
      case RecipientType.individual:
        return 'individual';
    }
  }

  static RecipientType fromString(String value) {
    switch (value) {
      case 'charity':
        return RecipientType.charity;
      case 'community':
        return RecipientType.community;
      case 'individual':
        return RecipientType.individual;
      default:
        return RecipientType.charity;
    }
  }
}

/// Bağış alıcısı kategorileri
enum CharityCategory {
  education,      // Eğitim ve Gelecek
  health,         // Sağlık ve Umut
  animals,        // Can Dostlarımız
  environment,    // Doğa ve Çevre
  humanitarian,   // İnsani Yardım
  accessibility,  // Engelsiz Yaşam
}

extension CharityCategoryExtension on CharityCategory {
  String get displayName {
    switch (this) {
      case CharityCategory.education:
        return 'Eğitim ve Gelecek';
      case CharityCategory.health:
        return 'Sağlık ve Umut';
      case CharityCategory.animals:
        return 'Can Dostlarımız';
      case CharityCategory.environment:
        return 'Doğa ve Çevre';
      case CharityCategory.humanitarian:
        return 'İnsani Yardım';
      case CharityCategory.accessibility:
        return 'Engelsiz Yaşam';
    }
  }

  String get value {
    switch (this) {
      case CharityCategory.education:
        return 'education';
      case CharityCategory.health:
        return 'health';
      case CharityCategory.animals:
        return 'animals';
      case CharityCategory.environment:
        return 'environment';
      case CharityCategory.humanitarian:
        return 'humanitarian';
      case CharityCategory.accessibility:
        return 'accessibility';
    }
  }

  static CharityCategory fromString(String value) {
    switch (value) {
      case 'education':
        return CharityCategory.education;
      case 'health':
        return CharityCategory.health;
      case 'animals':
        return CharityCategory.animals;
      case 'environment':
        return CharityCategory.environment;
      case 'humanitarian':
        return CharityCategory.humanitarian;
      case 'accessibility':
        return CharityCategory.accessibility;
      default:
        return CharityCategory.humanitarian;
    }
  }
  
  static List<CharityCategory> get allCategories => CharityCategory.values;
}

/// Bağış alıcısı modeli (Vakıf, Topluluk, Birey)
class CharityModel {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String? bannerUrl;
  final RecipientType type;
  final bool isActive;
  final bool isVerified;
  final double targetAmount;      // Hedef miktar
  final double collectedAmount;   // Toplanan miktar
  final int donorCount;           // Bağışçı sayısı
  final String? category;         // Kategori (eğitim, sağlık, vb.)
  final String? contactEmail;
  final String? contactPhone;
  final String? website;
  final String? address;
  final Map<String, dynamic>? socialLinks;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;        // Admin UID

  CharityModel({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.bannerUrl,
    required this.type,
    this.isActive = true,
    this.isVerified = false,
    this.targetAmount = 0,
    this.collectedAmount = 0,
    this.donorCount = 0,
    this.category,
    this.contactEmail,
    this.contactPhone,
    this.website,
    this.address,
    this.socialLinks,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  /// Hedef tamamlanma yüzdesi
  double get progressPercentage {
    if (targetAmount <= 0) return 0;
    return (collectedAmount / targetAmount * 100).clamp(0, 100);
  }

  /// Firestore'dan model oluştur
  factory CharityModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CharityModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['image_url'],
      bannerUrl: data['banner_url'],
      type: RecipientTypeExtension.fromString(data['type'] ?? 'charity'),
      isActive: data['is_active'] ?? true,
      isVerified: data['is_verified'] ?? false,
      targetAmount: (data['target_amount'] ?? 0).toDouble(),
      collectedAmount: (data['collected_amount'] ?? 0).toDouble(),
      donorCount: data['donor_count'] ?? 0,
      category: data['category'],
      contactEmail: data['contact_email'],
      contactPhone: data['contact_phone'],
      website: data['website'],
      address: data['address'],
      socialLinks: data['social_links'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      createdBy: data['created_by'],
    );
  }

  /// Model'den Firestore Map'e dönüştür
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'banner_url': bannerUrl,
      'type': type.value,
      'is_active': isActive,
      'is_verified': isVerified,
      'target_amount': targetAmount,
      'collected_amount': collectedAmount,
      'donor_count': donorCount,
      'category': category,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'website': website,
      'address': address,
      'social_links': socialLinks,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'created_by': createdBy,
    };
  }

  /// CopyWith metodu
  CharityModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? bannerUrl,
    RecipientType? type,
    bool? isActive,
    bool? isVerified,
    double? targetAmount,
    double? collectedAmount,
    int? donorCount,
    String? category,
    String? contactEmail,
    String? contactPhone,
    String? website,
    String? address,
    Map<String, dynamic>? socialLinks,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return CharityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      targetAmount: targetAmount ?? this.targetAmount,
      collectedAmount: collectedAmount ?? this.collectedAmount,
      donorCount: donorCount ?? this.donorCount,
      category: category ?? this.category,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      website: website ?? this.website,
      address: address ?? this.address,
      socialLinks: socialLinks ?? this.socialLinks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

/// Bağış kaydı modeli (detaylı raporlama için)
class DonationRecordModel {
  final String id;
  final String donorUid;
  final String donorName;
  final String? donorEmail;
  final String recipientId;
  final String recipientName;
  final RecipientType recipientType;
  final double amount;
  final DateTime donatedAt;
  final String? message;
  final bool isAnonymous;
  final bool isTransferred; // Para aktarımı yapıldı mı?
  final DateTime? transferredAt; // Aktarım tarihi

  DonationRecordModel({
    required this.id,
    required this.donorUid,
    required this.donorName,
    this.donorEmail,
    required this.recipientId,
    required this.recipientName,
    required this.recipientType,
    required this.amount,
    required this.donatedAt,
    this.message,
    this.isAnonymous = false,
    this.isTransferred = false,
    this.transferredAt,
  });

  factory DonationRecordModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    // Tarihi güvenli bir şekilde parse et - tüm olası alan adlarını kontrol et
    DateTime donatedAtDate = DateTime.now();
    final possibleTimestampFields = ['donated_at', 'created_at', 'timestamp', 'date'];
    for (var field in possibleTimestampFields) {
      final value = data[field];
      if (value is Timestamp) {
        donatedAtDate = value.toDate();
        break;
      }
    }
    
    DateTime? transferredAtDate;
    final transferredAtTimestamp = data['transferred_at'];
    if (transferredAtTimestamp is Timestamp) {
      transferredAtDate = transferredAtTimestamp.toDate();
    }
    
    // Recipient name için daha kapsamlı fallback - boş string kontrolü de ekle
    String recipientName = '';
    if (data['recipient_name'] != null && data['recipient_name'].toString().isNotEmpty) {
      recipientName = data['recipient_name'];
    } else if (data['charity_name'] != null && data['charity_name'].toString().isNotEmpty) {
      recipientName = data['charity_name'];
    } else if (data['target_name'] != null && data['target_name'].toString().isNotEmpty) {
      recipientName = data['target_name'];
    }
    
    return DonationRecordModel(
      id: doc.id,
      donorUid: data['donor_uid'] ?? data['user_id'] ?? '',
      donorName: data['donor_name'] ?? data['user_name'] ?? '',
      donorEmail: data['donor_email'],
      recipientId: data['recipient_id'] ?? data['charity_id'] ?? '',
      recipientName: recipientName,
      recipientType: RecipientTypeExtension.fromString(data['recipient_type'] ?? 'charity'),
      amount: (data['amount'] ?? data['hope_amount'] ?? 0).toDouble(),
      donatedAt: donatedAtDate,
      message: data['message'],
      isAnonymous: data['is_anonymous'] ?? false,
      isTransferred: data['is_transferred'] ?? false,
      transferredAt: transferredAtDate,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'donor_uid': donorUid,
      'donor_name': donorName,
      'donor_email': donorEmail,
      'recipient_id': recipientId,
      'recipient_name': recipientName,
      'recipient_type': recipientType.value,
      'amount': amount,
      'donated_at': Timestamp.fromDate(donatedAt),
      'message': message,
      'is_anonymous': isAnonymous,
      'is_transferred': isTransferred,
      'transferred_at': transferredAt != null ? Timestamp.fromDate(transferredAt!) : null,
    };
  }
  
  DonationRecordModel copyWith({
    bool? isTransferred,
    DateTime? transferredAt,
  }) {
    return DonationRecordModel(
      id: id,
      donorUid: donorUid,
      donorName: donorName,
      donorEmail: donorEmail,
      recipientId: recipientId,
      recipientName: recipientName,
      recipientType: recipientType,
      amount: amount,
      donatedAt: donatedAt,
      message: message,
      isAnonymous: isAnonymous,
      isTransferred: isTransferred ?? this.isTransferred,
      transferredAt: transferredAt ?? this.transferredAt,
    );
  }
}
