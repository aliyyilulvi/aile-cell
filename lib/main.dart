import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

// NOT: `flutterfire configure` komutu çalıştırıldığında bu dosya
// otomatik olarak oluşturulur (firebase_options.dart).
// Aşağıdaki import'u kendi projenizde oluşan dosyayla değiştirin.
import 'firebase_options.dart';

// Aile Cell — marka renkleri
const Color kPrimaryPurple = Color(0xFF4A148C); // koyu mor
const Color kAccentPurple = Color(0xFF7B1FA2); // orta mor
const Color kLightPurple = Color(0xFFE1BEE7); // açık mor (baloncuk vb.)
const Color kBackgroundPurple = Color(0xFFF3E5F5); // arka plan

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'Aile Cell',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: kPrimaryPurple,
            primary: kPrimaryPurple,
            secondary: kAccentPurple,
          ),
          scaffoldBackgroundColor: kBackgroundPurple,
          appBarTheme: const AppBarTheme(
            backgroundColor: kPrimaryPurple,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: kAccentPurple,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData) {
              return const HomeScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
