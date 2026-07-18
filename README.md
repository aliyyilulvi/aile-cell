# Aile Cell — Kurulum ve Mimari Rehberi

**Renk teması:** Mor (#4A148C koyu mor / #7B1FA2 orta mor). Logo `assets/logo.png` içinde hazır, `pubspec.yaml`'da `flutter_launcher_icons` ile otomatik olarak tüm Android ikon boyutlarına dönüştürülüyor.

## 1. Mimari Özet

```
[Telefon A] <--- WebRTC (ses + görüntü, P2P) ---> [Telefon B]
     |                                                  |
     |         Firestore (sinyalleşme,                  |
     +-------- mesajlar, kullanıcılar) -----------------+
```

- **Kimlik/Kayıt:** Firebase Authentication (kullanıcı adı → sahte e-posta
  dönüşümü ile e-posta/şifre altyapısı kullanılıyor).
- **Mesajlaşma:** Cloud Firestore, gerçek zamanlı (realtime) senkronizasyon
  sağlar.
- **Sesli/Görüntülü Arama:** WebRTC, ses ve görüntüyü doğrudan iki cihaz
  arasında taşır (peer-to-peer). Firestore burada sadece sinyalleşme
  (offer/answer/ICE) için kullanılıyor; medya verisi Firestore'dan geçmez.
  Sohbet ekranında iki ayrı buton var: telefon ikonu (sesli) ve kamera
  ikonu (görüntülü). `call_screen.dart` her ikisini de tek ekranda,
  `isVideoCall` parametresine göre yönetiyor.
- **Gizlilik:** Kullanıcılar sadece kullanıcı adıyla bulunup eklenebilir.

## 2. Neden "tamamen ücretsiz" demek karmaşık?

Uygulamanın kendisi ücretsiz olabilir, ama **arkasındaki sunucu
kaynaklarının bir maliyeti mutlaka vardır** — bu maliyeti ya sen (geliştirici)
üstlenirsin ya da kullanıcı sayısı arttıkça ücretsiz kotalar yetmez olur.
Somut olarak:

| Bileşen | Ücretsiz mi? | Sınırı |
|---|---|---|
| Firebase Authentication | Evet (Spark planı) | 50.000 aktif kullanıcı/ay |
| Firestore | Evet, sınırlı | Günde ~50.000 okuma / 20.000 yazma |
| STUN sunucusu (Google) | Evet, tamamen ücretsiz | Sadece bağlantı keşfi yapar, veri taşımaz |
| **TURN sunucusu** | **Kısmen** | Aşağıda açıklanıyor |

### STUN vs TURN farkı (önemli)
- **STUN**: İki cihazın birbirini "doğrudan" (aynı ağ/NAT arkasından) bulmasına
  yardım eder. Google'ın herkese açık ücretsiz STUN sunucularını
  (`stun.l.google.com:19302`) kullanabilirsin, sonsuza kadar ücretsiz.
- **TURN**: İki cihaz doğrudan birbirini bulamazsa (çoğu mobil veri/CGNAT
  durumunda bu olur), ses verisi bir TURN sunucusu üzerinden **röle**
  edilir. Bu, sunucu tarafında bant genişliği tüketir, dolayısıyla tam
  anlamıyla ücretsiz bir TURN sunucusu **kalıcı ve sınırsız olarak yoktur**.
  Seçeneklerin:
  1. **Metered.ca** (eski adıyla CoTURN as a Service) — aylık 50 GB'a kadar
     ücretsiz TURN sunar, küçük/orta ölçekli test için yeterli.
  2. **Kendi coturn sunucunu kur** — bir bulut sunucuda (örn. Oracle Cloud
     Free Tier'da sonsuza kadar ücretsiz bir VM ile) açık kaynak `coturn`
     yazılımını kurarsın; sunucu maliyeti sıfıra yakın olur ama yönetimi
     sana kalır.
  3. Sadece STUN ile bırakabilirsin: aramaların büyük kısmı çalışır ama bazı
     ağlarda (özellikle kurumsal Wi-Fi, bazı operatör CGNAT'ları) bağlantı
     kurulamayabilir.

Koddaki `webrtc_service.dart` içinde TURN bilgisi eklemek için ayrılmış
yorum satırı bırakıldı — `_iceServers` map'ine kendi TURN bilgilerini
eklemen yeterli.

## 3. Kurulum Adımları

Burada iki yol var. **Yol A**, bilgisayarına Flutter/Android Studio kurmadan
GitHub üzerinden otomatik APK üretmeni sağlar (önerilen, en az sürtünmeli
yol). **Yol B**, klasik yerel kurulumdur.

---

### YOL A — GitHub Actions ile (bilgisayara hiçbir şey kurmadan)

1. **Firebase projesi oluştur:** console.firebase.google.com → yeni proje.
   - Authentication → "Email/Password" sağlayıcısını etkinleştir.
   - Firestore Database → test modunda oluştur.
   - Proje Ayarları → "Uygulama Ekle" → Android → paket adı olarak
     `com.ailecell.app` gir → **google-services.json dosyasını indir.**

2. **İki dosyayı doldur (bu projede zaten şablonları var):**
   - `android/app/google-services.json` → indirdiğin gerçek dosyayla
     **tamamen değiştir** (üzerine kopyala-yapıştır).
   - `lib/firebase_options.dart` → Firebase Console'da aynı ekranda
     görünen `apiKey`, `appId`, `messagingSenderId`, `projectId`,
     `storageBucket` değerlerini ilgili yerlere yapıştır.
   (İkisini de GitHub'ın web arayüzünden, dosyaya tıklayıp kalem/edit
   ikonuyla düzenleyebilirsin — bilgisayarına bir şey kurmana gerek yok.)

3. **GitHub'a yükle:**
   - GitHub'da yeni, boş bir repo oluştur (Public veya Private, ikisi de olur).
   - Bu zip'in içindekileri (klasör yapısıyla birlikte) repo'ya yükle:
     repo sayfasında "Add file → Upload files" ile tüm klasörü
     sürükle-bırak yapabilirsin, GitHub alt klasörleri otomatik korur.

4. **Otomatik derlemeyi izle:**
   - Yükleme bitince repo'nun üst menüsünden **Actions** sekmesine git.
   - "APK Üret" adlı workflow otomatik başlamış olacak (yaklaşık 3-5 dakika sürer).
   - Bittiğinde workflow'un sayfasına gir, en altta **Artifacts** bölümünde
     "aile-cell-apk" adlı bir zip göreceksin — indir, içinden
     `app-release.apk` dosyasını telefonuna at ve kur.

   Not: Workflow dosyası zaten `.github/workflows/build-apk.yml` içinde
   hazır; hiçbir ek ayara gerek yok, "main" dalına her yükleme yaptığında
   otomatik yeniden APK üretir.

5. **Telefonda kurulum:** APK'yı telefona indirdikten sonra "Bilinmeyen
   kaynaklardan yükleme" iznini açman gerekebilir (Ayarlar → Güvenlik).

---

### YOL B — Yerel kurulum (Flutter + Android Studio)

1. **Flutter SDK kur:** flutter.dev üzerinden (3.x sürümü).
2. **Firebase projesi oluştur:** console.firebase.google.com → yeni proje.
   - Authentication → "Email/Password" sağlayıcısını etkinleştir.
   - Firestore Database → test modunda oluştur (sonra kuralları sıkılaştır).
3. **FlutterFire CLI ile bağla:**
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Bu komut otomatik olarak `lib/firebase_options.dart` ve
   `android/app/google-services.json` dosyalarının üzerine kendi gerçek
   Firebase bilgilerini yazar (bu projede şu an sadece doldurulması
   gereken şablon halleri var).
4. **Bağımlılıkları indir:**
   ```bash
   flutter pub get
   ```
5. **Firestore güvenlik kuralları** (örnek, `Firestore > Rules`):
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read: if request.auth != null;
         allow write: if request.auth != null && request.auth.uid == userId;
         match /contacts/{contactId} {
           allow read, write: if request.auth != null && request.auth.uid == userId;
         }
       }
       match /chats/{chatId} {
         allow read, write: if request.auth != null &&
           request.auth.uid in resource.data.participants;
         allow create: if request.auth != null;
         match /messages/{messageId} {
           allow read, create: if request.auth != null;
         }
       }
       match /calls/{callId} {
         allow read, write: if request.auth != null;
         match /{sub}/{doc} {
           allow read, write: if request.auth != null;
         }
       }
     }
   }
   ```
6. **Uygulama ikonunu üret** (logo zaten `assets/logo.png` içinde hazır):
   ```bash
   flutter pub run flutter_launcher_icons
   ```
   Bu komut, mor arka planlı logoyu otomatik olarak tüm Android ikon
   boyutlarına (`mipmap-*` klasörleri) dönüştürür.
7. **Çalıştır / APK üret:**
   ```bash
   flutter run                     # test cihazında çalıştır
   flutter build apk --release     # yayın APK'sı üret
   ```
   Üretilen dosya: `build/app/outputs/flutter-apk/app-release.apk`

## 4. Görüntülü Arama Hakkında

Sohbet ekranında iki ayrı buton var:
- **Telefon ikonu** → sesli arama (`isVideoCall: false`)
- **Kamera ikonu** → görüntülü arama (`isVideoCall: true`)

`call_screen.dart` şunları destekler:
- Karşılıklı kamera görüntüsü (tam ekran karşı taraf, küçük pencere kendi görüntün)
- Mikrofon aç/kapat, kamera aç/kapat butonları
- Ön/arka kamera arasında geçiş (`Icons.cameraswitch`)
- Arayan taraf `isVideo` bilgisini Firestore'daki `calls/{callId}` belgesine
  yazıyor; aranan taraf bu bilgiye bakarak otomatik olarak kamerasını da
  açıyor (yani gelen aramanın sesli mi görüntülü mü olduğunu doğru algılıyor).

Görüntülü aramanın veri kullanımı sesli aramadan çok daha fazladır — bu
yüzden Faz 2'de (mobil veride TURN sunucusu eklenince) görüntülü arama
için TURN sunucu bant genişliği maliyeti de artacaktır. Kullanıcılarına
"görüntülü arama mobil veride daha fazla veri harcar" şeklinde bir uyarı
göstermeni öneririz.

## 5. Eksik / Genişletilebilecek Kısımlar

- **Gelen arama bildirimi:** Şu an `CallScreen` sadece arayan taraf için
  otomatik başlıyor. Karşı tarafın "gelen arama" ekranını görmesi için
  `calls` koleksiyonunu dinleyen bir arka plan servisi (ör. Firebase Cloud
  Messaging ile push bildirimi) eklemen gerekir.
- **Görüntülü arama:** Artık uygulandı (bkz. Bölüm 4). Kalite/performans
  ayarları (çözünürlük, bit hızı) `webrtc_service.dart` içindeki
  `getUserMedia` kısıtlarından ayarlanabilir.
- **Profil fotoğrafı, "yazıyor..." göstergesi, okundu bilgisi** gibi
  WhatsApp detayları bu iskelete Firestore alanları eklenerek
  genişletilebilir.
