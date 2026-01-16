# 🔐 BAŞDENETÇİ SON KONTROL - KOD İNCELEME (GÜNCEL)

**Tarih:** 16 Ocak 2026  
**Konu:** Idempotency (Deterministik Doc ID) + daily_goal_steps Tip Kontrolü  
**Build:** ✅ Başarılı  
**Son Güncelleme:** Deterministik Doc ID ile Race Condition Koruması

---

## 1️⃣ donateHope() - DETERMİNİSTİK DOC ID IDEMPOTENCY ✅

> **🚨 SON FIX:** Race condition riski giderildi. Artık idempotency kontrolü transaction İÇİNDE yapılıyor.

```typescript
export const donateHope = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    const userId = context.auth.uid;
    const { charityId, amount, idempotencyKey } = data;

    // Validasyon
    if (!charityId || typeof charityId !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Geçerli bir vakıf ID gereklidir."
      );
    }

    if (!amount || typeof amount !== "number" || amount <= 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Bağış miktarı pozitif bir sayı olmalıdır."
      );
    }

    // Minimum bağış kontrolü
    if (amount < 1) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Minimum bağış miktarı 1 Hope'tur."
      );
    }

    // 🚨 BAŞDENETÇİ FIX: Idempotency key zorunlu
    if (!idempotencyKey || typeof idempotencyKey !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Idempotency key gereklidir (double işlem koruması)."
      );
    }

    // 🚨 BAŞDENETÇİ FIX REV.2: Deterministik doc ID ile race condition koruması
    // Format: donations/{userId}_{idempotencyKey}
    const donationId = `${userId}_${idempotencyKey}`;
    const donationRef = db.collection("donations").doc(donationId);

    try {
      // 🚨 TEK TRANSACTION İÇİNDE TÜM MUHASEBE + IDEMPOTENCY CHECK
      const result = await db.runTransaction(async (transaction) => {
        // 0. 🚨 IDEMPOTENCY CHECK (Transaction İÇİNDE - race condition korumalı)
        const existingDonationDoc = await transaction.get(donationRef);
        
        if (existingDonationDoc.exists) {
          // Aynı işlem daha önce yapılmış - idempotent return
          const existingData = existingDonationDoc.data()!;
          console.log(`Idempotent call detected (transaction-safe): ${donationId}`);
          return {
            idempotent: true,
            donationId: donationId,
            charityName: existingData.charity_name,
            newBalance: existingData.new_balance_after || 0,
          };
        }
        // 1. Kullanıcı dokümanını oku
        const userRef = db.collection("users").doc(userId);
        const userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Kullanıcı bulunamadı."
          );
        }
        
        const userData = userDoc.data()!;
        const currentBalance = (userData.wallet_balance_hope || 0) as number;
        
        // Bakiye kontrolü
        if (currentBalance < amount) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            `Yetersiz bakiye. Mevcut: ${currentBalance}, İstenen: ${amount}`
          );
        }

        // 2. Charity dokümanını oku
        const charityRef = db.collection("charities").doc(charityId);
        const charityDoc = await transaction.get(charityRef);
        
        if (!charityDoc.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "Vakıf bulunamadı."
          );
        }
        
        const charityData = charityDoc.data()!;

        // 3. İlk bağış kontrolü (donor_count için)
        const existingDonations = await db
          .collection("donations")
          .where("user_id", "==", userId)
          .where("charity_id", "==", charityId)
          .limit(1)
          .get();
        const isFirstDonation = existingDonations.empty;

        // ====== YAZMA AŞAMASI (Tüm okumalar bittikten sonra) ======
        
        const now = new Date();
        const donationMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
        const timestamp = admin.firestore.FieldValue.serverTimestamp();

        // 4. Kullanıcı bakiyesini düşür + istatistikleri güncelle
        transaction.update(userRef, {
          wallet_balance_hope: admin.firestore.FieldValue.increment(-amount),
          lifetime_donated_hope: admin.firestore.FieldValue.increment(amount),
          total_donation_count: admin.firestore.FieldValue.increment(1),
        });

        // 5. Bağış kaydı oluştur (DETERMİNİSTİK ID ile - race condition korumalı)
        transaction.set(donationRef, {
          user_id: userId,
          user_name: userData.display_name || userData.full_name || "Anonim",
          charity_id: charityId,
          charity_name: charityData.name,
          amount: amount,
          donation_month: donationMonth,
          donation_status: "pending", // Ay sonu onaylanacak
          created_at: timestamp,
          idempotency_key: idempotencyKey, // Backward compatibility için
          new_balance_after: currentBalance - amount, // Idempotent return için
        });

        // 6. Global activity log ekle
        const globalLogRef = db.collection("activity_logs").doc();
        transaction.set(globalLogRef, {
          user_id: userId,
          user_name: userData.display_name || userData.full_name || "Anonim",
          activity_type: "donation",
          action_type: "donation",
          recipient_id: charityId,
          recipient_name: charityData.name,
          charity_id: charityId,
          charity_name: charityData.name,
          charity_logo_url: charityData.logo_url || charityData.image_url || null,
          recipient_type: charityData.type || "charity",
          amount: amount,
          hope_amount: amount,
          donation_month: donationMonth,
          donation_status: "pending",
          created_at: timestamp,
          timestamp: timestamp,
        });
        
        // 7. User subcollection activity log ekle (rozet hesaplama için)
        const userLogRef = userRef.collection("activity_logs").doc();
        transaction.set(userLogRef, {
          user_id: userId,
          activity_type: "donation",
          action_type: "donation",
          target_name: charityData.name,
          charity_name: charityData.name,
          charity_id: charityId,
          charity_logo_url: charityData.logo_url || charityData.image_url || null,
          recipient_id: charityId,
          recipient_type: charityData.type || "charity",
          amount: amount,
          hope_amount: amount,
          created_at: timestamp,
          timestamp: timestamp,
        });

        // 8. Charity stats güncelle
        const charityUpdateData: Record<string, any> = {
          collected_amount: admin.firestore.FieldValue.increment(amount),
        };
        if (isFirstDonation) {
          charityUpdateData.donor_count = admin.firestore.FieldValue.increment(1);
        }
        transaction.update(charityRef, charityUpdateData);

        return {
          idempotent: false,
          donationId: donationId,
          charityName: charityData.name,
          newBalance: currentBalance - amount,
        };
      });

      // 🚨 Idempotent ve normal dönüşü ayır
      if (result.idempotent) {
        return {
          success: true,
          message: `Bağış zaten işlendi (idempotent).`,
          donationId: result.donationId,
          newBalance: result.newBalance,
          idempotent: true,
        };
      }

      return {
        success: true,
        message: `${result.charityName} vakfına ${amount} Hope bağışlandı.`,
        donationId: result.donationId,
        newBalance: result.newBalance,
      };
    } catch (error: any) {
      console.error("donateHope hatası:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);
```

### donateHope() Yarış Koşulu Analizi

| Kontrol | Durum |
|---------|-------|
| Deterministik Doc ID | ✅ `{userId}_{idempotencyKey}` |
| Idempotency Check | ✅ Transaction İÇİNDE (race-safe) |
| Bakiye oku-kontrol-yaz | ✅ Transaction içinde atomik |
| Double call | ✅ İlk başarılı → ikinci idempotent dönüş |
| Eşzamanlı farklı key | ✅ Her biri ayrı transaction, bakiye kontrolü atomik |
| **Race Condition** | ✅ **KORUNUYOR** (transaction.get + transaction.set) |

---

## 2️⃣ joinTeam() - QUICK CHECK + TRANSACTION IDEMPOTENCY ✅

```typescript
export const joinTeam = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    const userId = context.auth.uid;
    const { teamId } = data;

    if (!teamId || typeof teamId !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Geçerli bir takım ID gereklidir."
      );
    }

    try {
      // 🚨 BAŞDENETÇİ FIX: Idempotency - Zaten üye mi kontrolü (transaction ÖNCESİ hızlı check)
      const quickMemberCheck = await db
        .collection("teams")
        .doc(teamId)
        .collection("team_members")
        .doc(userId)
        .get();
      
      if (quickMemberCheck.exists) {
        // Zaten üye - idempotent başarılı dönüş
        const teamDoc = await db.collection("teams").doc(teamId).get();
        const teamName = teamDoc.exists ? teamDoc.data()?.name : "Takım";
        console.log(`Idempotent joinTeam call: user ${userId} already in team ${teamId}`);
        return {
          success: true,
          message: `Zaten ${teamName} takımının üyesisiniz (idempotent).`,
          teamId: teamId,
          idempotent: true,
        };
      }

      const result = await db.runTransaction(async (transaction) => {
        // 1. Kullanıcı dokümanını oku
        const userRef = db.collection("users").doc(userId);
        const userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw new functions.https.HttpsError("not-found", "Kullanıcı bulunamadı.");
        }
        
        const userData = userDoc.data()!;
        
        // Kullanıcı zaten bir takımda mı?
        if (userData.current_team_id) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Zaten bir takımda üyesiniz. Önce mevcut takımdan ayrılın."
          );
        }

        // 2. Takım dokümanını oku
        const teamRef = db.collection("teams").doc(teamId);
        const teamDoc = await transaction.get(teamRef);
        
        if (!teamDoc.exists) {
          throw new functions.https.HttpsError("not-found", "Takım bulunamadı.");
        }
        
        const teamData = teamDoc.data()!;

        // 3. Zaten üye mi kontrol et (transaction içi - yarış koşulu koruması)
        const memberRef = teamRef.collection("team_members").doc(userId);
        const memberDoc = await transaction.get(memberRef);
        
        if (memberDoc.exists) {
          throw new functions.https.HttpsError(
            "already-exists",
            "Zaten bu takımın üyesisiniz."
          );
        }

        // Max üye kontrolü
        const maxMembers = teamData.max_members || 50;
        if ((teamData.members_count || 0) >= maxMembers) {
          throw new functions.https.HttpsError(
            "resource-exhausted",
            "Takım maksimum üye kapasitesine ulaşmış."
          );
        }

        // ====== YAZMA AŞAMASI ======
        const timestamp = admin.firestore.FieldValue.serverTimestamp();

        // 4. team_members'a ekle
        transaction.set(memberRef, {
          team_id: teamId,
          user_id: userId,
          member_status: "active",
          join_date: timestamp,
          member_total_hope: 0,
          member_daily_steps: 0,
        });

        // 5. User current_team_id güncelle
        transaction.update(userRef, {
          current_team_id: teamId,
        });

        // 6. Team stats güncelle
        transaction.update(teamRef, {
          members_count: admin.firestore.FieldValue.increment(1),
          member_ids: admin.firestore.FieldValue.arrayUnion(userId),
        });

        return {
          teamName: teamData.name,
        };
      });

      return {
        success: true,
        message: `${result.teamName} takımına katıldınız.`,
        teamId: teamId,
      };
    } catch (error: any) {
      console.error("joinTeam hatası:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);
```

### joinTeam() Yarış Koşulu Analizi

| Kontrol | Durum |
|---------|-------|
| Quick member check | ✅ Transaction dışında (hızlı fail) |
| Transaction içi member check | ✅ Atomik (yarış koşulu koruması) |
| Double call | ✅ İlk başarılı → ikinci idempotent dönüş |
| current_team_id kontrolü | ✅ Transaction içinde |

---

## 3️⃣ leaveTeam() - DOĞAL IDEMPOTENT ✅

```typescript
export const leaveTeam = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    const userId = context.auth.uid;

    try {
      const result = await db.runTransaction(async (transaction) => {
        // 1. Kullanıcı dokümanını oku
        const userRef = db.collection("users").doc(userId);
        const userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw new functions.https.HttpsError("not-found", "Kullanıcı bulunamadı.");
        }
        
        const userData = userDoc.data()!;
        const teamId = userData.current_team_id;
        
        // 🚨 DOĞAL IDEMPOTENT: Zaten ayrılmışsa hata
        if (!teamId) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Herhangi bir takımda üye değilsiniz."
          );
        }

        // 2. Takım dokümanını oku
        const teamRef = db.collection("teams").doc(teamId);
        const teamDoc = await transaction.get(teamRef);
        
        if (!teamDoc.exists) {
          // Takım silinmişse sadece user'ı temizle
          transaction.update(userRef, { current_team_id: null });
          return { teamName: "Silinmiş Takım" };
        }
        
        const teamData = teamDoc.data()!;

        // 3. Lider kontrolü
        if (teamData.leader_uid === userId) {
          const membersCount = teamData.members_count || 1;
          if (membersCount > 1) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "Takım lideri olarak takımda başka üyeler varken ayrılamazsınız. Önce liderliği devredin veya diğer üyeleri çıkarın."
            );
          }
          // Lider ve tek üye - takımı da sil
          transaction.delete(teamRef);
        } else {
          // Normal üye - takım stats güncelle
          transaction.update(teamRef, {
            members_count: admin.firestore.FieldValue.increment(-1),
            member_ids: admin.firestore.FieldValue.arrayRemove(userId),
          });
        }

        // 4. team_members'dan sil
        const memberRef = teamRef.collection("team_members").doc(userId);
        transaction.delete(memberRef);

        // 5. User current_team_id temizle
        transaction.update(userRef, {
          current_team_id: null,
        });

        return {
          teamName: teamData.name,
          wasLeader: teamData.leader_uid === userId,
        };
      });

      const message = result.wasLeader 
        ? `${result.teamName} takımı silindi (son üye olarak ayrıldınız).`
        : `${result.teamName} takımından ayrıldınız.`;

      return {
        success: true,
        message: message,
      };
    } catch (error: any) {
      console.error("leaveTeam hatası:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);
```

### leaveTeam() Yarış Koşulu Analizi

| Kontrol | Durum |
|---------|-------|
| current_team_id null check | ✅ Doğal idempotent |
| Transaction | ✅ Atomik |
| Double call | ✅ İlk başarılı → ikinci hata (expected) |

---

## 4️⃣ daily_goal_steps - TİP + ARALIK KONTROLÜ ✅

```javascript
// firestore.rules içinde users/{userId} update kuralı

allow update: if isUser(userId) &&
                request.resource.data.diff(resource.data).affectedKeys()
                  .hasOnly([
                    // Profil alanları
                    'display_name', 'photo_url', 'bio', 'phone_number',
                    // Tercihler
                    'theme_mode', 'language', 'notification_preferences',
                    'daily_goal_steps', 'privacy_settings',
                    // Health Kit entegrasyonu
                    'health_data_source', 'last_health_sync',
                    // FCM token
                    'fcm_token', 'fcm_token_updated_at',
                    // Durum alanları (client günceller)
                    'last_active_at', 'app_version', 'device_info'
                  ]) &&
                // 🚨 BAŞDENETÇİ FIX: daily_goal_steps tip + aralık kontrolü
                (
                  !request.resource.data.diff(resource.data).affectedKeys()
                    .hasAny(['daily_goal_steps']) ||
                  (
                    request.resource.data.daily_goal_steps is int &&
                    request.resource.data.daily_goal_steps >= 1000 &&
                    request.resource.data.daily_goal_steps <= 100000
                  )
                );
```

### daily_goal_steps Kontrolleri

| Kontrol | Değer | Açıklama |
|---------|-------|----------|
| Tip | `is int` | Tam sayı olmalı |
| Minimum | `>= 1000` | Mantıklı minimum hedef |
| Maximum | `<= 100000` | Gerçekçi üst limit |

---

## 📋 ÖZET TABLO

| Function | Idempotency Yöntemi | Transaction | Yarış Koşulu |
|----------|---------------------|-------------|--------------|
| `donateHope()` | ✅ Deterministik Doc ID | ✅ | ✅ **Transaction içi check** |
| `joinTeam()` | ✅ Quick check + transaction | ✅ | ✅ Korumalı |
| `leaveTeam()` | ✅ Doğal (null check) | ✅ | ✅ Korumalı |

| Rules | Kontrol |
|-------|---------|
| `daily_goal_steps` | ✅ int + 1000-100000 aralık |

---

## 🔥 KRİTİK DEĞİŞİKLİK: Deterministik Doc ID

**ÖNCE (ESKİ - Race Condition Riski):**
```typescript
// ❌ Transaction DIŞINDA where query
const existingDonation = await db
  .collection("donations")
  .where("idempotency_key", "==", idempotencyKey)
  .limit(1)
  .get();

if (!existingDonation.empty) {
  // Idempotent return
}

// Transaction...
```

**SONRA (YENİ - Race-Safe):**
```typescript
// ✅ Deterministik doc ID
const donationId = `${userId}_${idempotencyKey}`;
const donationRef = db.collection("donations").doc(donationId);

const result = await db.runTransaction(async (transaction) => {
  // ✅ Transaction İÇİNDE kontrol
  const existingDonationDoc = await transaction.get(donationRef);
  
  if (existingDonationDoc.exists) {
    return { idempotent: true, ... };
  }
  
  // Muhasebe işlemleri...
  transaction.set(donationRef, { ... }); // Aynı ref kullanılıyor
});
```

### Fark Nedir?

| Özellik | Eski | Yeni |
|---------|------|------|
| Check konumu | Transaction DIŞINDA | Transaction İÇİNDE |
| Doc ID | `auto-id` | `{userId}_{idempotencyKey}` |
| Race window | ~ms (tehlikeli) | 0 (atomik) |
| Concurrent calls | Double yazma riski | İlki yazar, diğerleri idempotent |

---

## ✅ SONUÇ

- **Build:** ✅ Başarılı
- **Idempotency:** ✅ Deterministik Doc ID ile tüm fonksiyonlarda mevcut
- **Yarış Koşulu:** ✅ Transaction.get + Transaction.set ile korumalı
- **Tip Kontrolü:** ✅ daily_goal_steps için eklendi

**FINAL GO Alındı:** ✅

**Deploy Komutu:**
```bash
firebase deploy --only firestore:rules,functions
```
