import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  // Orientasi default saat boot; akan dioverride di runtime per-perangkat.
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
      title: 'Kasir',
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF2C3640),
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: const Color(0xFF7FB4A9),
          secondary: const Color(0xFFB6C7C2),
        ),
      ),
      home: const SplashScreen(), // <- di sini
    );
  }
}

