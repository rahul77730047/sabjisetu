import 'package:flutter/material.dart';

import '../core/api_client.dart';
import 'home_shell.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.api,
  });

  final ApiClient api;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    final Future<bool> authCheck = widget.api.hasToken().timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    ).catchError((_) => false);

    await Future<void>.delayed(
      const Duration(seconds: 3),
    );

    bool isLoggedIn = false;
    try {
      isLoggedIn = await authCheck;
    } catch (_) {
      isLoggedIn = false;
    }

    if (!mounted) return;

    final Widget nextScreen;

    if (isLoggedIn) {
      nextScreen = HomeShell(
        api: widget.api,
      );
    } else {
      nextScreen = LoginScreen(
        api: widget.api,
      );
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return nextScreen;
        },
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(
          milliseconds: 400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF002B0F),
      // 1. Removed SafeArea so the image can bleed edge-to-edge
      body: SizedBox.expand(
        child: Image.asset(
          'assets/Splash screen.png',

          // 2. BoxFit.cover scales the image to fill the screen, cropping edges as needed
          fit: BoxFit.cover,

          // 3. Focuses the crop on the center. Change to Alignment.topCenter if your logo/focus is high up.
          alignment: Alignment.center,

          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          gaplessPlayback: true,
          errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
              ) {
            return const ColoredBox(
              color: Color(0xFF002B0F),
            );
          },
        ),
      ),
    );
  }
}
