# DENETÇİ TALEPLERİ ANALİZ RAPORU

**Tarih:** 16 Ocak 2026  
**Hazırlayan:** Teknik Ekip  
**Konu:** Denetçi bulgularına yanıt ve aksiyon planı

---

## 📋 MEVCUT DURUM TESPİTLERİ

| Tespit | Durum | Dosya/Satır |
|--------|-------|-------------|
| **App Check** | `AppleProvider.debug` + `AndroidProvider.debug` - **HER ZAMAN DEBUG** | `main.dart#L98-L100` |
| **App Check fail** | `catch` ile "devam ediliyor" - **FAIL-OPEN** | `main.dart#L103` |
| **Simulated steps** | Android'de Health Connect yoksa `_useSimulatedData = true` + conversion açık | `health_service.dart#L55-L60` |
| **Storage team_logos** | `isAuthenticated()` yeterli - **HERKES YAZABİLİR** | `storage.rules#L43-L47` |

---

## ✅ DENETÇİ TALEPLERİNE CEVAP

### TAM KATILIYORUM - YAPILACAK

| # | Madde | Risk | Tahmini Süre |
|---|-------|------|--------------|
| **P0-1** | Step→Hope transaction | Finansal bütünlük | 2-3 saat |
| **P0-2** | Simulated steps prod kapatma | Fraud kapısı | 30 dk |
| **P1-1** | Monthly job idempotency | Muhasebe | 1 saat |
| **P1-2** | App Check prod + enforcement | Abuse engeli | 2 saat |
| **P2-1** | Conversion ledger | Denetim izi | 1 saat |
| **P2-2** | admins read daraltma | Gizlilik | 5 dk |
| **EK** | Storage team_logos fix | Yetki | 10 dk |

---

## 🚨 RİSK ANALİZİ: "KURALLARI BAŞTAN YAZMAK GEREKİR Mİ?"

### **HAYIR!** Mevcut organizasyon korunacak.

Değişiklikler **izole ve hedefli** olacak:

| Değişecek | Değişmeyecek |
|-----------|--------------|
| `step_conversion_service.dart` (transaction) | Tüm UI akışları |
| `health_service.dart` (simulated kapatma) | Dashboard, Donation, Teams |
| `monthly-hope-calculator.ts` (status check) | Firestore data model |
| `main.dart` (App Check provider) | Routing, Auth akışı |
| `firestore.rules` (2 küçük ekleme) | Mevcut tüm kurallar |
| `storage.rules` (team_logos fix) | profile_photos |

---

## 📊 HER DEĞİŞİKLİĞİN RİSK MATRİSİ

### P0-1: Transaction (En Karmaşık)

**Mevcut:**
```dart
batch.update(stepRef)
batch.update(userRef)
batch.commit()
```

**Yeni:**
```dart
transaction içinde:
1. stepDoc oku
2. remaining = daily_steps - converted_steps
3. stepsToConvert <= remaining kontrolü
4. converted_steps + wallet güncellemesi
```

**Risk Değerlendirmesi:**
- ✅ UI değişmiyor (`convertSteps()` aynı signature)
- ✅ Firestore path'ler değişmiyor
- ⚠️ Transaction fail durumu handle edilmeli (retry logic)
- ⚠️ daily_steps doc yoksa oluşturma (upsert)

**Etkilenen akışlar:** SADECE conversion - diğer her şey aynı

---

### P0-2: Simulated Steps Kapatma

**Mevcut (health_service.dart:55-60):**
```dart
if (sdkStatus == HealthConnectSdkStatus.sdkUnavailable) {
  _useSimulatedData = true;  // ❌ FRAUD KAPISI
  _isAuthorized = true;
  _todaySteps = _generateSimulatedSteps();
  return true;
}
```

**Yeni:**
```dart
if (sdkStatus == HealthConnectSdkStatus.sdkUnavailable) {
  if (kReleaseMode) {
    _useSimulatedData = false;
    _isAuthorized = false;  // Conversion izni yok
    _todaySteps = 0;
    return false;  // Health desteklenmiyor
  }
  // Debug'da simulated devam
}
```

**Risk Değerlendirmesi:**
- ✅ Debug modda test hâlâ mümkün
- ✅ UI'da "Adım takibi desteklenmiyor" mesajı gösterilebilir
- ⚠️ Health Connect olmayan Android'lerde conversion disabled olacak (doğru davranış)

---

### P1-1: Monthly Job Idempotency

**Mevcut:**
```typescript
await db.collection("monthly_hope_value").doc(monthKey).set(monthlyData);
```

**Yeni:**
```typescript
const existingDoc = await db.collection("monthly_hope_value").doc(monthKey).get();
if (existingDoc.exists) {
  const status = existingDoc.data()?.status;
  if (['calculated', 'approved', 'completed'].includes(status)) {
    console.log(`⚠️ ${monthKey} zaten işlenmiş, çıkılıyor`);
    return;
  }
}
await db.collection("monthly_hope_value").doc(monthKey).set(monthlyData);
```

**Risk Değerlendirmesi:** ✅ Sıfır - sadece guard ekleniyor

---

### P1-2: App Check Prod

**Mevcut (main.dart:98-100):**
```dart
await FirebaseAppCheck.instance.activate(
  appleProvider: AppleProvider.debug,
  androidProvider: AndroidProvider.debug,
);
```

**Yeni:**
```dart
await FirebaseAppCheck.instance.activate(
  appleProvider: kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
  androidProvider: kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
);
```

**Risk Değerlendirmesi:**
- ⚠️ Play Integrity ve Device Check kurulumu gerekli (Firebase Console)
- ⚠️ Yanlış config = legitimate user'lar etkilenir
- ✅ Gradual rollout ile test edilebilir

---

### P2-2: admins Read Daraltma

**Mevcut (firestore.rules):**
```plaintext
match /admins/{adminId} {
  allow read: if isAuthenticated();  // ❌ Herkes tüm admin'leri görebilir
}
```

**Yeni:**
```plaintext
match /admins/{adminId} {
  allow read: if isAuthenticated() && request.auth.uid == adminId;  // ✅ Sadece kendisi
}
```

**Risk Değerlendirmesi:** ✅ Sıfır - mevcut client zaten sadece kendi doc'unu okuyor

---

### EK: Storage team_logos Fix

**Mevcut (storage.rules):**
```plaintext
match /team_logos/{teamId}.jpg {
  allow write: if isAuthenticated();  // ❌ Herkes yazabilir
}
```

**Çözüm Önerileri:**
1. Cloud Function ile handle (önerilen)
2. Metadata kontrolü ile team_leader_uid == request.auth.uid

**Risk Değerlendirmesi:** ⚠️ Bu biraz daha karmaşık - Cloud Function önerilir

---

## 📋 ÖNERİLEN UYGULAMA SIRASI

| Sıra | Madde | Süre | Bozulma Riski |
|------|-------|------|---------------|
| 1 | P0-2: Simulated steps kapatma | 30 dk | ❌ Yok |
| 2 | P2-2: admins read daraltma | 5 dk | ❌ Yok |
| 3 | P1-1: Monthly job idempotency | 1 saat | ❌ Yok |
| 4 | P0-1: Transaction + çift dönüşüm | 2-3 saat | ⚠️ Düşük (dikkatli test) |
| 5 | P1-2: App Check prod | 2 saat | ⚠️ Orta (config gerekli) |
| 6 | P2-1: Conversion ledger | 1 saat | ❌ Yok |
| 7 | EK: Storage team_logos | 30 dk | ❌ Yok |

---

## ❓ ONAY GEREKTİREN SORULAR

1. **App Check için Firebase Console erişimi var mı?** (Play Integrity / Device Check kurulumu gerekecek)

2. **Health Connect olmayan Android cihazlarda conversion tamamen engellensin mi?** (Denetçi bunu istiyor)

3. **Önce kolay olanlardan mı başlansın?** (P0-2, P2-2, P1-1 hızlıca hallolur, sonra karmaşık olanlar)

---

## 📈 TOPLAM TAHMİNİ SÜRE

| Kategori | Süre |
|----------|------|
| P0 (Release Blocker) | ~3 saat |
| P1 (Store Öncesi Zorunlu) | ~3 saat |
| P2 (İyileştirme) | ~1.5 saat |
| **TOPLAM** | **~7.5 saat** |

---

## ✅ DENETÇİYE VERİLECEK KANITLAR (Her Madde İçin)

1. **Kod snippet'i** (değişen satırlar)
2. **Test senaryosu:**
   - Conversion: "iki kez bas" / race condition denemesi
   - Monthly job: "aynı monthKey iki kez run" denemesi
   - App Check: "App Check yokken istek reddi"

---

**RAPOR SONU**
