"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyEmailCode = exports.sendVerificationCode = void 0;
const admin = require("firebase-admin");
const https_1 = require("firebase-functions/v2/https");
const nodemailer = require("nodemailer");
const db = admin.firestore();
// Gmail SMTP transporter
const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
        user: "hopesteps.app@gmail.com",
        pass: "adcehygbxsqrtsqi", // App Password (boşluksuz)
    },
});
/**
 * 6 haneli rastgele kod oluştur
 */
function generateVerificationCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}
/**
 * Email doğrulama kodu gönder
 * 🚨 P1-2: App Check enforcement aktif
 */
exports.sendVerificationCode = (0, https_1.onCall)({ enforceAppCheck: true }, async (request) => {
    var _a;
    // Auth kontrolü
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Oturum açmanız gerekiyor");
    }
    const uid = request.auth.uid;
    try {
        // Kullanıcı bilgilerini al
        const userRecord = await admin.auth().getUser(uid);
        const email = userRecord.email;
        if (!email) {
            throw new https_1.HttpsError("failed-precondition", "Email adresi bulunamadı");
        }
        // Zaten doğrulanmış mı kontrol et
        const userDoc = await db.doc(`users/${uid}`).get();
        if (userDoc.exists && ((_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.email_verified) === true) {
            throw new https_1.HttpsError("already-exists", "Email zaten doğrulanmış");
        }
        // Son 1 dakika içinde kod gönderilmiş mi kontrol et (spam önleme)
        const recentCodes = await db.collection("verification_codes")
            .where("uid", "==", uid)
            .where("created_at", ">", admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60 * 1000) // 1 dakika önce
        ))
            .get();
        if (!recentCodes.empty) {
            throw new https_1.HttpsError("resource-exhausted", "Lütfen 1 dakika bekleyin");
        }
        // 6 haneli kod oluştur
        const code = generateVerificationCode();
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 dakika geçerli
        // Eski kodları sil
        const oldCodes = await db.collection("verification_codes")
            .where("uid", "==", uid)
            .get();
        const batch = db.batch();
        oldCodes.docs.forEach(doc => batch.delete(doc.ref));
        // Yeni kodu kaydet
        const codeRef = db.collection("verification_codes").doc();
        batch.set(codeRef, {
            uid: uid,
            email: email,
            code: code,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
            attempts: 0,
            verified: false,
        });
        await batch.commit();
        // Email gönder (Nodemailer ile)
        const mailOptions = {
            from: '"One Hope Step" <hopesteps.app@gmail.com>',
            to: email,
            subject: "One Hope Step - Doğrulama Kodunuz",
            html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background: #ffffff;">
          <div style="text-align: center; margin-bottom: 30px; padding: 20px;">
            <h1 style="font-size: 32px; font-weight: bold; margin: 0; background: linear-gradient(135deg, #6EC6B5 0%, #F2C94C 50%, #E07A5F 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;">One Hope Step</h1>
            <p style="color: #6EC6B5; margin-top: 5px; font-size: 14px;">Her adım bir umut</p>
          </div>
          
          <p style="font-size: 16px; color: #333;">Merhaba,</p>
          
          <p style="font-size: 16px; color: #333;">
            Email adresinizi doğrulamak için aşağıdaki kodu kullanın:
          </p>
          
          <div style="background: linear-gradient(135deg, #E8F7F5 0%, #FFF9E6 100%); border-radius: 16px; padding: 30px; text-align: center; margin: 30px 0; border: 2px solid #6EC6B5;">
            <span style="font-size: 42px; font-weight: bold; letter-spacing: 10px; color: #333;">
              ${code}
            </span>
          </div>
          
          <p style="font-size: 14px; color: #666;">
            Bu kod <strong style="color: #E07A5F;">10 dakika</strong> içinde geçerliliğini yitirecektir.
          </p>
          
          <p style="font-size: 14px; color: #666;">
            Eğer bu kodu siz talep etmediyseniz, bu emaili görmezden gelebilirsiniz.
          </p>
          
          <hr style="border: none; border-top: 2px solid #E8F7F5; margin: 30px 0;">
          
          <p style="font-size: 12px; color: #999; text-align: center;">
            One Hope Step © 2026 | Her adımınız umut olsun 🌟
          </p>
        </div>
      `,
            text: `One Hope Step - Doğrulama Kodunuz: ${code}\n\nBu kod 10 dakika içinde geçerliliğini yitirecektir.`,
        };
        await transporter.sendMail(mailOptions);
        console.log(`✅ Doğrulama kodu gönderildi: ${email}`);
        return {
            success: true,
            message: "Doğrulama kodu gönderildi",
            email: maskEmail(email),
        };
    }
    catch (error) {
        console.error("❌ sendVerificationCode hatası:", error);
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        throw new https_1.HttpsError("internal", "Kod gönderilemedi");
    }
});
/**
 * Email doğrulama kodunu kontrol et
 * 🚨 P1-2: App Check enforcement aktif
 */
exports.verifyEmailCode = (0, https_1.onCall)({ enforceAppCheck: true }, async (request) => {
    var _a;
    // Auth kontrolü
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Oturum açmanız gerekiyor");
    }
    const uid = request.auth.uid;
    const code = (_a = request.data) === null || _a === void 0 ? void 0 : _a.code;
    if (!code || typeof code !== "string" || code.length !== 6) {
        throw new https_1.HttpsError("invalid-argument", "Geçersiz kod formatı");
    }
    try {
        // En son kodu bul
        const codesSnapshot = await db.collection("verification_codes")
            .where("uid", "==", uid)
            .where("verified", "==", false)
            .orderBy("created_at", "desc")
            .limit(1)
            .get();
        if (codesSnapshot.empty) {
            throw new https_1.HttpsError("not-found", "Doğrulama kodu bulunamadı. Yeni kod isteyin.");
        }
        const codeDoc = codesSnapshot.docs[0];
        const codeData = codeDoc.data();
        // Süre kontrolü
        const expiresAt = codeData.expires_at.toDate();
        if (new Date() > expiresAt) {
            throw new https_1.HttpsError("deadline-exceeded", "Kodun süresi dolmuş. Yeni kod isteyin.");
        }
        // Deneme sayısı kontrolü (max 5)
        if (codeData.attempts >= 5) {
            throw new https_1.HttpsError("resource-exhausted", "Çok fazla yanlış deneme. Yeni kod isteyin.");
        }
        // Kod doğru mu?
        if (codeData.code !== code) {
            // Deneme sayısını artır
            await codeDoc.ref.update({
                attempts: admin.firestore.FieldValue.increment(1),
            });
            const remaining = 5 - (codeData.attempts + 1);
            throw new https_1.HttpsError("invalid-argument", `Yanlış kod. ${remaining} deneme hakkınız kaldı.`);
        }
        // Kod doğru! Kullanıcıyı doğrulanmış olarak işaretle
        const batch = db.batch();
        // Verification code'u güncelle
        batch.update(codeDoc.ref, {
            verified: true,
            verified_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        // User belgesini güncelle
        batch.update(db.doc(`users/${uid}`), {
            email_verified: true,
            email_verified_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        await batch.commit();
        // Firebase Auth emailVerified'ı da güncelle (opsiyonel ama tutarlılık için)
        // Not: Bu sadece custom token ile mümkün, normal Auth ile değil
        // Onun yerine Firestore field'ını kullanacağız
        console.log(`✅ Email doğrulandı: ${uid}`);
        return {
            success: true,
            message: "Email başarıyla doğrulandı!",
        };
    }
    catch (error) {
        console.error("❌ verifyEmailCode hatası:", error);
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        throw new https_1.HttpsError("internal", "Doğrulama başarısız");
    }
});
/**
 * Email adresini maskele (gizlilik için)
 */
function maskEmail(email) {
    const [localPart, domain] = email.split("@");
    if (localPart.length <= 2) {
        return `${localPart[0]}***@${domain}`;
    }
    return `${localPart.slice(0, 2)}***@${domain}`;
}
//# sourceMappingURL=email-verification.js.map