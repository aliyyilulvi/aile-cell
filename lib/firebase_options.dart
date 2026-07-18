// BU DOSYAYI KENDİ FIREBASE PROJENİN BİLGİLERİYLE DOLDURMAN GEREKİYOR.
//
// Nereden bulunur: Firebase Console → Proje Ayarları (dişli ikonu) →
// "Genel" sekmesi → altta "Uygulamalarınız" bölümünde Android uygulaman
// (paket adı: com.ailecell.app) → orada listelenen değerleri buraya kopyala.
//
// Bu dosya, normalde `flutterfire configure` komutuyla otomatik üretilir;
// biz burada bilgisayara hiçbir şey kurmadan, elle doldurabilmen için
// hazır bir şablon bıraktık.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions sadece Android için yapılandırıldı.',
    );
  }
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC8sABGwZ2sQO42u7LHOMZhHVTHWun2h94',
    appId: '1:282977545553:android:89cd4f6da301f8e9437770',
    messagingSenderId: '282977545553',
    projectId: 'aile-cell',
    storageBucket: 'aile-cell.firebasestorage.app',
  );
}
