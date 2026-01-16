# FAZA 6 - Dead Code Temizliği Planı

**Tarih:** 15 Ocak 2026  
**Durum:** PLANLANMIŞ

---

## 📋 Yapılacak İşlemler

### 6.1 main_new.dart Silme (BUG-012)
**Dosya:** `lib/main_new.dart`

### 6.2 Dashboard Backup Dosyaları Silme (CODE-005)
| # | Dosya |
|---|-------|
| 1 | `lib/screens/dashboard/dashboard_screen_backup.dart` |
| 2 | `lib/screens/dashboard/dashboard_screen_new.dart` |
| 3 | `lib/screens/dashboard/dashboard_screen_orig.dart` |
| 4 | `lib/screens/dashboard/dashboard_screen_recovered.dart` |
| 5 | `lib/screens/dashboard/dashboard_screen_simple.dart` |

---

## 🔍 Silmeden Önce Kontroller

### Kontrol 1: Import Kontrolü
```bash
# Bu dosyaların hiçbir yerden import edilmediğini doğrula
grep -r "main_new" lib/
grep -r "dashboard_screen_backup" lib/
grep -r "dashboard_screen_new" lib/
grep -r "dashboard_screen_orig" lib/
grep -r "dashboard_screen_recovered" lib/
grep -r "dashboard_screen_simple" lib/
```

### Kontrol 2: Aktif Kullanım
- Ana `dashboard_screen.dart` mevcut ve aktif ✅
- Ana `main.dart` mevcut ve aktif ✅

---

## ⚠️ Risk Analizi

| Risk | Seviye | Açıklama | Önlem |
|------|--------|----------|-------|
| Yanlış dosya silme | 🟢 DÜŞÜK | Aktif dosya silinebilir | Import kontrolü yapılacak |
| Gerekli kod kaybı | 🟢 DÜŞÜK | Backup'ta önemli kod olabilir | Silmeden önce diff kontrolü |
| Git history kaybı | 🟢 YOK | Git'te kalacak | Gerekirse restore edilebilir |

---

## 📊 Etki Analizi

### Olumlu Etkiler
| Etki | Açıklama |
|------|----------|
| **Kod temizliği** | 6 gereksiz dosya kaldırılacak |
| **flutter analyze** | ~100+ warning azalacak |
| **Build boyutu** | Minimal azalma (dead code elimination zaten var) |
| **Bakım kolaylığı** | Daha temiz proje yapısı |

### Olumsuz Etkiler
| Etki | Açıklama |
|------|----------|
| **Hiçbiri** | Dosyalar kullanılmıyor |

---

## 🔄 Rollback Planı

```bash
# Silinen dosyaları geri almak için:
git checkout HEAD~1 -- lib/main_new.dart
git checkout HEAD~1 -- lib/screens/dashboard/dashboard_screen_backup.dart
git checkout HEAD~1 -- lib/screens/dashboard/dashboard_screen_new.dart
git checkout HEAD~1 -- lib/screens/dashboard/dashboard_screen_orig.dart
git checkout HEAD~1 -- lib/screens/dashboard/dashboard_screen_recovered.dart
git checkout HEAD~1 -- lib/screens/dashboard/dashboard_screen_simple.dart
```

---

## ✅ Başarı Kriterleri

| # | Kriter | Beklenen |
|---|--------|----------|
| 1 | `flutter analyze` | ✅ No errors |
| 2 | `flutter build` | ✅ Başarılı |
| 3 | Uygulama çalışıyor | ✅ Normal |
| 4 | Dosyalar silindi | ✅ 6 dosya |

---

## 📁 Özet

| Metrik | Değer |
|--------|-------|
| **Silinecek dosya sayısı** | 6 |
| **Risk seviyesi** | 🟢 ÇOK DÜŞÜK |
| **Tahmini süre** | 15-30 dakika |
| **Rollback** | Git'ten kolayca |

---

## 🚀 Başlamak İçin

FAZA 6'yı başlatmak için onay verin, şu adımlar izlenecek:

1. Import kontrolü yapılacak (grep)
2. Dosyalar silinecek
3. `flutter analyze` çalıştırılacak
4. Sonuç raporu oluşturulacak

---

**HAZIRIZ - Onay bekleniyor** 🟢
