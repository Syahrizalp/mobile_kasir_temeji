// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/screens/splash_screen.dart'; // Ubah ke LoginScreen kalau ingin langsung ke login

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi data format tanggal untuk locale Indonesia (hindari LocaleDataException)
  await initializeDateFormatting('id_ID', null);

  // Orientasi default saat boot; bisa dioverride di runtime per device
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const KasirApp());
}

class KasirApp extends StatelessWidget {
  const KasirApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kasir Temeji',

      // Tema dasar (gelap) + warna kustom
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF2C3640),
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: const Color(0xFF7FB4A9), // aksen hijau kebiruan lembut
          secondary: const Color(0xFFB6C7C2),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF3A444E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFF7FB4A9), width: 1.4),
          ),
          hintStyle: TextStyle(color: Color(0xFF9BA8B2)),
          labelStyle: TextStyle(color: Color(0xFFCFD8DC)),
        ),
      ),

      // Lokalisasi Material/Cupertino/Widget
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', ''), // fallback opsional
      ],
      locale: const Locale('id', 'ID'),

      // Layar awal aplikasi
      home: const SplashScreen(),
    );
  }
}
