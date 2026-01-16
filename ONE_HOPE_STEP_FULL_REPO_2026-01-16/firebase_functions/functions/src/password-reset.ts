import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as nodemailer from "nodemailer";

const db = admin.firestore();

// Gmail SMTP transporter
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "hopesteps.app@gmail.com",
    pass: "adcehygbxsqrtsqi", // App Password
  },
});

/**
 * 6 haneli rastgele kod oluştur
 */
function generateResetCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Email adresini maskele
 */
function maskEmail(email: string): string {
  const [localPart, domain] = email.split("@");
  if (localPart.length <= 2) {
    return `${localPart[0]}***@${domain}`;
  }
  return `${localPart.slice(0, 2)}***@${domain}`;
}

/**
 * Şifre sıfırlama kodu gönder
 * 🚨 P1-2: App Check enforcement aktif
 */
export const sendPasswordResetCode = onCall(
  { enforceAppCheck: true },
  async (request) => {
  const email = request.data?.email;

  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Email adresi gerekli");
  }

  const normalizedEmail = email.toLowerCase().trim();

  try {
    // Kullanıcı var mı kontrol et
    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(normalizedEmail);
    } catch (e) {
      // Güvenlik için kullanıcı bulunamadığını söyleme
      throw new HttpsError("not-found", "Bu email ile kayıtlı kullanıcı bulunamadı");
    }

    // Son 1 dakika içinde kod gönderilmiş mi kontrol et
    const recentCodes = await db.collection("password_reset_codes")
      .where("email", "==", normalizedEmail)
      .where("created_at", ">", admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 60 * 1000)
      ))
      .get();

    if (!recentCodes.empty) {
      throw new HttpsError(
        "resource-exhausted",
        "Lütfen 1 dakika bekleyin"
      );
    }

    // 6 haneli kod oluştur
    const code = generateResetCode();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 dakika geçerli

    // Eski kodları sil
    const oldCodes = await db.collection("password_reset_codes")
      .where("email", "==", normalizedEmail)
      .get();

    const batch = db.batch();
    oldCodes.docs.forEach(doc => batch.delete(doc.ref));

    // Yeni kodu kaydet
    const codeRef = db.collection("password_reset_codes").doc();
    batch.set(codeRef, {
      uid: userRecord.uid,
      email: normalizedEmail,
      code: code,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
      attempts: 0,
      used: false,
    });

    await batch.commit();

    // Email gönder
    const mailOptions = {
      from: '"One Hope Step" <hopesteps.app@gmail.com>',
      to: normalizedEmail,
      subject: "One Hope Step - Şifre Sıfırlama Kodunuz",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background: #ffffff;">
          <div style="text-align: center; margin-bottom: 30px; padding: 20px;">
            <h1 style="font-size: 32px; font-weight: bold; margin: 0; background: linear-gradient(135deg, #6EC6B5 0%, #F2C94C 50%, #E07A5F 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;">One Hope Step</h1>
            <p style="color: #6EC6B5; margin-top: 5px; font-size: 14px;">Her adım bir umut</p>
          </div>
          
          <p style="font-size: 16px; color: #333;">Merhaba,</p>
          
          <p style="font-size: 16px; color: #333;">
            Şifrenizi sıfırlamak için aşağıdaki kodu kullanın:
          </p>
          
          <div style="background: linear-gradient(135deg, #FFF0E8 0%, #FFF9E6 100%); border-radius: 16px; padding: 30px; text-align: center; margin: 30px 0; border: 2px solid #E07A5F;">
            <span style="font-size: 42px; font-weight: bold; letter-spacing: 10px; color: #333;">
              ${code}
            </span>
          </div>
          
          <p style="font-size: 14px; color: #666;">
            Bu kod <strong style="color: #E07A5F;">10 dakika</strong> içinde geçerliliğini yitirecektir.
          </p>
          
          <p style="font-size: 14px; color: #666;">
            Eğer şifre sıfırlama talebinde bulunmadıysanız, bu emaili görmezden gelebilirsiniz.
          </p>
          
          <hr style="border: none; border-top: 2px solid #FFF0E8; margin: 30px 0;">
          
          <p style="font-size: 12px; color: #999; text-align: center;">
            One Hope Step © 2026 | Her adımınız umut olsun 🌟
          </p>
        </div>
      `,
      text: `One Hope Step - Şifre Sıfırlama Kodunuz: ${code}\n\nBu kod 10 dakika içinde geçerliliğini yitirecektir.`,
    };

    await transporter.sendMail(mailOptions);

    console.log(`✅ Şifre sıfırlama kodu gönderildi: ${normalizedEmail}`);

    return {
      success: true,
      message: "Şifre sıfırlama kodu gönderildi",
      email: maskEmail(normalizedEmail),
    };
  } catch (error: any) {
    console.error("❌ sendPasswordResetCode hatası:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError("internal", "Kod gönderilemedi");
  }
});

/**
 * Şifre sıfırlama kodunu doğrula ve yeni şifreyi kaydet
 * 🚨 P1-2: App Check enforcement aktif
 */
export const resetPasswordWithCode = onCall(
  { enforceAppCheck: true },
  async (request) => {
  const { email, code, newPassword } = request.data || {};

  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Email adresi gerekli");
  }

  if (!code || typeof code !== "string" || code.length !== 6) {
    throw new HttpsError("invalid-argument", "Geçersiz kod formatı");
  }

  if (!newPassword || typeof newPassword !== "string" || newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Şifre en az 6 karakter olmalı");
  }

  const normalizedEmail = email.toLowerCase().trim();

  try {
    // En son kodu bul
    const codesSnapshot = await db.collection("password_reset_codes")
      .where("email", "==", normalizedEmail)
      .where("used", "==", false)
      .orderBy("created_at", "desc")
      .limit(1)
      .get();

    if (codesSnapshot.empty) {
      throw new HttpsError("not-found", "Geçerli sıfırlama kodu bulunamadı. Yeni kod isteyin.");
    }

    const codeDoc = codesSnapshot.docs[0];
    const codeData = codeDoc.data();

    // Süre kontrolü
    const expiresAt = codeData.expires_at.toDate();
    if (new Date() > expiresAt) {
      throw new HttpsError("deadline-exceeded", "Kodun süresi dolmuş. Yeni kod isteyin.");
    }

    // Deneme sayısı kontrolü (max 5)
    if (codeData.attempts >= 5) {
      throw new HttpsError(
        "resource-exhausted",
        "Çok fazla yanlış deneme. Yeni kod isteyin."
      );
    }

    // Kod doğru mu?
    if (codeData.code !== code) {
      // Deneme sayısını artır
      await codeDoc.ref.update({
        attempts: admin.firestore.FieldValue.increment(1),
      });

      const remaining = 5 - (codeData.attempts + 1);
      throw new HttpsError(
        "invalid-argument",
        `Yanlış kod. ${remaining} deneme hakkınız kaldı.`
      );
    }

    // Kod doğru! Şifreyi değiştir
    const uid = codeData.uid;
    
    // Firebase Auth'ta şifreyi güncelle
    await admin.auth().updateUser(uid, {
      password: newPassword,
    });

    // Kodu kullanıldı olarak işaretle
    await codeDoc.ref.update({
      used: true,
      used_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Şifre başarıyla sıfırlandı: ${normalizedEmail}`);

    return {
      success: true,
      message: "Şifreniz başarıyla güncellendi!",
    };
  } catch (error: any) {
    console.error("❌ resetPasswordWithCode hatası:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError("internal", "Şifre sıfırlama başarısız");
  }
});
