import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app.dart';
import '../core/api_client.dart';
import '../core/localization.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.api,
  });

  final ApiClient api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final loc = Localization();
  final TextEditingController _user = TextEditingController();
  final TextEditingController _pass = TextEditingController();

  bool _loading = false;
  bool _hidePass = true;
  String? _error;

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
    });

    if (_user.text.trim().isEmpty || _pass.text.trim().isEmpty) {
      setState(() {
        _error = '${loc.translate('id and password')} ${loc.translate('is required')}';
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await widget.api.login(_user.text.trim(), _pass.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (c) => HomeShell(api: widget.api)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      final errStr = e.toString().replaceAll('Exception: ', '').trim();
      String userMsg;

      if (errStr.contains('Server connection failed') ||
          errStr.contains('SocketException') ||
          errStr.contains('Connection refused') ||
          errStr.contains('Network is unreachable') ||
          errStr.contains('ClientException') ||
          errStr.contains('Failed host lookup')) {
        userMsg = loc.translate('Server connection failed. Check network or server address.');
      } else if (errStr.contains('Invalid username or password') ||
          errStr.contains('Invalid credentials') ||
          errStr.contains('invalid credentials') ||
          errStr.contains('Unauthorized')) {
        userMsg = loc.translate('invalid credentials');
      } else if (errStr.contains('Internal server error') || errStr.contains('500')) {
        userMsg = loc.translate('Server error. Please try again later.');
      } else {
        userMsg = errStr;
      }

      setState(() {
        _error = userMsg;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor;
    final onAccent = AppTheme.onAccentColor;
    final accentSoft = AppTheme.accentSoft;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand Badge
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: accentSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(Icons.storefront_rounded, color: accent, size: 48),
                ),
                const SizedBox(height: 20),

                // App Title & Tagline
                Text(
                  'SabziSetu',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF171A1F),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    loc.translate('tagline'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: onAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE7E9ED), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        loc.translate('login'),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF171A1F),
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Username Field
                      TextField(
                        controller: _user,
                        decoration: InputDecoration(
                          labelText: loc.translate('id'),
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextField(
                        controller: _pass,
                        obscureText: _hidePass,
                        decoration: InputDecoration(
                          labelText: loc.translate('password'),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _hidePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _hidePass = !_hidePass;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _loading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(onAccent),
                                ),
                              )
                            : Text(
                                loc.translate('login'),
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
