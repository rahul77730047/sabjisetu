import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/api_client.dart';
import 'core/localization.dart';
import 'screens/splash_screen.dart';

final ValueNotifier<Color> themeColorNotifier = ValueNotifier<Color>(const Color(0xFF20252B));

class AppTheme {
  static Color get accentColor => themeColorNotifier.value;

  // Calculates contrast-safe foreground (dark text for light accents, white text for dark accents)
  static Color get onAccentColor => accentColor.computeLuminance() > 0.45
      ? const Color(0xFF171A1F)
      : Colors.white;

  // Helper method for any background color contrast
  static Color readableForeground(Color bg) => bg.computeLuminance() > 0.45
      ? const Color(0xFF171A1F)
      : Colors.white;

  // Soft tinted background suitable for selected rows, badges, and active pills
  static Color get accentSoft => accentColor.withValues(alpha: 0.12);
}

class SabziSetuApp extends StatefulWidget {
  const SabziSetuApp({super.key});

  @override
  State<SabziSetuApp> createState() => _SabziSetuAppState();
}

class _SabziSetuAppState extends State<SabziSetuApp> {
  final ApiClient api = ApiClient();
  final Localization loc = Localization();

  @override
  void initState() {
    super.initState();
    loc.addListener(() => setState(() {}));
    themeColorNotifier.addListener(() => setState(() {}));
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    try {
      final settings = await api.settings();
      final hex = settings['theme_color']?.toString();
      if (hex != null && hex.isNotEmpty) {
        final parsed = _parseHexColor(hex);
        if (parsed != null) {
          themeColorNotifier.value = parsed;
        }
      }
    } catch (_) {}
  }

  Color? _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor;
    final onAccent = AppTheme.onAccentColor;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SabziSetu',

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          primary: accent,
          onPrimary: onAccent,
          secondary: const Color(0xFFE59A2F),
          tertiary: const Color(0xFF4F8A68),
          surface: Colors.white,
          onSurface: const Color(0xFF171A1F),
        ),

        textTheme: GoogleFonts.poppinsTextTheme().copyWith(
          headlineSmall: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF171A1F),
          ),
          titleMedium: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF171A1F),
          ),
          bodyMedium: GoogleFonts.poppins(
            color: const Color(0xFF171A1F),
          ),
          bodySmall: GoogleFonts.poppins(
            color: const Color(0xFF747B84),
          ),
        ),

        scaffoldBackgroundColor: const Color(0xFFF6F7F9),

        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF6F7F9),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
            color: const Color(0xFF171A1F),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(
            color: accent,
          ),
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(
              color: Color(0xFFE7E9ED),
              width: 1,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFFE7E9ED),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFFE7E9ED),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: accent,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: onAccent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),

      // App hamesha splash screen se start hogi.
      home: SplashScreen(api: api),
    );
  }
}
