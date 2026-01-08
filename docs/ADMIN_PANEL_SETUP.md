# Admin Panel Kurulum Rehberi

## 🚀 Hızlı Başlangıç

Admin Panel'i kullanmak için aşağıdaki adımları izleyin.

---

## 1. İlk Admin Kullanıcısı Oluşturma

Firebase Console üzerinden ilk admin kullanıcısını manuel olarak oluşturmanız gerekiyor.

### Adım 1: Firebase Console'a Gidin
1. [Firebase Console](https://console.firebase.google.com/) adresine gidin
2. Projenizi seçin (`bir-adim-umut`)
3. Sol menüden **Firestore Database** seçin

### Adım 2: Admins Koleksiyonunu Oluşturun
1. **Start collection** butonuna tıklayın
2. Collection ID: `admins`
3. **Next** butonuna tıklayın

### Adım 3: Admin Dökümanı Ekleyin
1. Document ID: `<ADMIN_KULLANICI_UID>` (Firebase Auth'tan alın)
2. Aşağıdaki alanları ekleyin:

| Alan | Tip | Değer |
|------|-----|-------|
| `email` | string | admin@biradimumut.com |
| `name` | string | Super Admin |
| `role` | string | super_admin |
| `is_active` | boolean | true |
| `created_at` | timestamp | (şu anki tarih) |
| `permissions` | array | ["users", "teams", "charities", "donations", "notifications", "badges", "stats", "logs"] |

### Not: Kullanıcı UID Nasıl Bulunur?
1. Firebase Console → Authentication → Users
2. İlgili kullanıcının UID'sini kopyalayın

---

## 2. Admin Panel'e Erişim

Admin Panel'e erişmek için:

### Flutter Uygulaması İçinden
```dart
// Yönlendirme
Navigator.pushNamed(context, '/admin');

// Veya doğrudan
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => AdminPanelScreen()),
);
```

### Web URL (Flutter Web için)
```
https://yourapp.web.app/#/admin
```

---

## 3. Admin Koleksiyonları

Admin Panel aşağıdaki Firestore koleksiyonlarını kullanır:

| Koleksiyon | Açıklama |
|------------|----------|
| `admins` | Admin kullanıcıları |
| `admin_stats` | Dashboard istatistikleri |
| `admin_logs` | Admin işlem logları |
| `charities` | Vakıf/Topluluk/Bireyler |
| `donations` | Bağış kayıtları |
| `badge_definitions` | Rozet tanımları |
| `broadcast_notifications` | Toplu bildirimler |
| `daily_stats` | Günlük istatistikler |

---

## 4. Admin Rolleri ve İzinleri

### Super Admin
- Tüm özelliklere erişim
- Diğer adminleri yönetebilir
- Kritik verileri silebilir

### Admin
- Kullanıcı, takım, vakıf yönetimi
- İstatistikleri görüntüleme
- Bildirim gönderme

### Moderator
- Kullanıcıları görüntüleme
- Raporları görüntüleme
- Yorum moderasyonu

### İzin Yapısı
```json
{
  "permissions": [
    "users",        // Kullanıcı yönetimi
    "teams",        // Takım yönetimi
    "charities",    // Vakıf yönetimi
    "donations",    // Bağış raporları
    "notifications",// Bildirim gönderme
    "badges",       // Rozet yönetimi
    "stats",        // İstatistikler
    "logs"          // İşlem logları
  ]
}
```

---

## 5. Firestore Güvenlik Kuralları

Güvenlik kuralları otomatik olarak yapılandırılmıştır. Kuralları deploy etmek için:

```bash
firebase deploy --only firestore:rules
```

---

## 6. Admin Panel Özellikleri

### 📊 Dashboard
- Toplam kullanıcı sayısı
- Günlük aktif kullanıcı
- Toplam adım / Hope dönüşümü
- Toplam bağış miktarı
- Grafikler ve trendler

### 👥 Kullanıcı Yönetimi
- Kullanıcı listesi ve arama
- Kullanıcı detayları
- Ban/Unban işlemleri
- Hope bakiyesi düzenleme

### 👥 Takım Yönetimi
- Takım listesi
- Takım detayları
- Takım silme

### 🏛️ Vakıf/Topluluk/Birey Yönetimi
- Yeni ekleme
- Düzenleme
- Aktif/Pasif durumu
- Hedef belirleme

### 💰 Bağış Raporları
- Tarih bazlı filtreleme
- Alıcı bazlı özet
- Detaylı liste
- Excel export

### 🚶 Adım/Hope İstatistikleri
- Aylık bazda veriler
- 12 aylık geçmiş
- Grafik görünümü

### 🔔 Bildirim Yönetimi
- Toplu bildirim gönderme
- Şablonlar
- Gönderim geçmişi

### 🏅 Rozet Yönetimi
- Rozet tanımlama
- Seviye ve kriterler
- Ödül belirleme

### 📈 Analitik
- İndirme sayıları (iOS/Android)
- Reklam gelirleri
- Platform dağılımı

### 📝 İşlem Logları
- Tüm admin işlemleri
- Tarih bazlı filtreleme
- İşlem detayları

---

## 7. Sorun Giderme

### "Permission Denied" Hatası
1. Admin koleksiyonunda dökümanınız var mı kontrol edin
2. `is_active: true` olduğundan emin olun
3. Firebase Auth ile oturum açtığınızdan emin olun

### İstatistikler Görünmüyor
1. `admin_stats` koleksiyonunda veri olduğundan emin olun
2. Cloud Function'ları deploy edin (istatistik hesaplama için)

### Bildirimler Gönderilmiyor
1. Firebase Cloud Messaging yapılandırmasını kontrol edin
2. `broadcast_notifications` koleksiyonuna yazılıp yazılmadığını kontrol edin

---

## 8. Geliştirme Notları

### Yeni Admin Özelliği Eklemek
1. `lib/services/admin_service.dart` dosyasına servis metodu ekleyin
2. İlgili ekranı `lib/screens/admin/` altına oluşturun
3. `AdminPanelScreen` içindeki sidebar'a menü ekleyin

### İzin Kontrolü
```dart
// Servis içinde
Future<bool> hasPermission(String permission) async {
  final admin = await getCurrentAdmin();
  return admin?.permissions.contains(permission) ?? false;
}

// Ekranda kullanım
if (await _adminService.hasPermission('users')) {
  // İşlem yap
}
```

---

## 📞 Destek

Sorularınız için: admin@biradimumut.com
