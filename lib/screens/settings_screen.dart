import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app.dart';
import '../core/api_client.dart';
import '../core/localization.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.api,
  });

  final ApiClient api;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final loc = Localization();

  final TextEditingController n = TextEditingController();
  final TextEditingController o = TextEditingController();
  final TextEditingController t = TextEditingController();
  final TextEditingController c = TextEditingController();
  final TextEditingController lst = TextEditingController();
  final TextEditingController themeHex = TextEditingController();

  // Change Password Controllers
  final TextEditingController curPass = TextEditingController();
  final TextEditingController newPass = TextEditingController();
  final TextEditingController confPass = TextEditingController();

  bool _hideCurPass = true;
  bool _hideNewPass = true;
  bool _hideConfPass = true;
  bool passLoading = false;

  Map<String, dynamic>? currentBusiness;
  Map<String, dynamic>? masters;
  bool loading = true;
  bool whatsappSendAll = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    n.dispose();
    o.dispose();
    t.dispose();
    c.dispose();
    lst.dispose();
    themeHex.dispose();
    curPass.dispose();
    newPass.dispose();
    confPass.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; });
    try {
      final res = await Future.wait([
        widget.api.settings(),
        widget.api.masters(),
      ]);

      if (!mounted) return;
      currentBusiness = res[0] as Map<String, dynamic>;
      masters = res[1] as Map<String, dynamic>;

      n.text = currentBusiness!['name']?.toString() ?? 'SabziSetu';
      o.text = currentBusiness!['owner']?.toString() ?? 'Owner';
      t.text = currentBusiness!['tagline']?.toString() ?? '';
      c.text = currentBusiness!['currency']?.toString() ?? '₹';
      lst.text = currentBusiness!['low_stock_threshold_kg']?.toString() ?? currentBusiness!['lowStockThresholdKg']?.toString() ?? '50';
      themeHex.text = currentBusiness!['theme_color']?.toString() ?? currentBusiness!['themeColor']?.toString() ?? '#173F35';
      whatsappSendAll = currentBusiness!['whatsapp_send_all_enabled'] ?? currentBusiness!['whatsappSendAllEnabled'] ?? true;

      // Update global theme color if valid
      final parsedColor = _parseHexColor(themeHex.text);
      if (parsedColor != null) {
        themeColorNotifier.value = parsedColor;
      }
    } catch (_) {}
    if (mounted) setState(() { loading = false; });
  }

  Future<void> saveBusinessSettings() async {
    final hex = themeHex.text.trim().toUpperCase();
    final parsed = _parseHexColor(hex);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid HEX color code. Use format #173F35.')),
      );
      return;
    }

    try {
      final threshold = num.tryParse(lst.text.trim()) ?? 50;
      final updated = await widget.api.saveSettings({
        'name': n.text.trim(),
        'owner': o.text.trim(),
        'tagline': t.text.trim(),
        'currency': c.text.trim(),
        'theme_color': hex,
        'themeColor': hex,
        'low_stock_threshold_kg': threshold,
        'lowStockThresholdKg': threshold,
        'whatsapp_send_all_enabled': whatsappSendAll,
        'whatsappSendAllEnabled': whatsappSendAll,
      });

      final savedColorHex = (updated['theme_color'] ?? updated['themeColor'] ?? hex).toString();
      final savedColor = _parseHexColor(savedColorHex) ?? parsed;

      themeHex.text = savedColorHex;
      themeColorNotifier.value = savedColor;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('Settings saved.'))),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg')),
        );
      }
    }
  }

  Future<void> saveBusinessRules() async {
    try {
      final threshold = num.tryParse(lst.text.trim()) ?? 50;
      await widget.api.saveSettings({
        'low_stock_threshold_kg': threshold,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business rules updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> toggleWhatsAppSendAll(bool enabled) async {
    final previous = whatsappSendAll;
    setState(() { whatsappSendAll = enabled; });
    try {
      await widget.api.updateWhatsAppSendAll(enabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WhatsApp "Send to All" ${enabled ? 'enabled' : 'disabled'}.')),
        );
      }
    } catch (e) {
      setState(() { whatsappSendAll = previous; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update setting: $e')),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final cur = curPass.text.trim();
    final nPass = newPass.text.trim();
    final cPass = confPass.text.trim();

    if (cur.isEmpty || nPass.isEmpty || cPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All password fields are required.')),
      );
      return;
    }

    if (nPass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 8 characters long.')),
      );
      return;
    }

    if (nPass != cPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password and confirm password do not match.')),
      );
      return;
    }

    if (cur == nPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be different from current password.')),
      );
      return;
    }

    setState(() { passLoading = true; });

    try {
      await widget.api.changePassword(cur, nPass);
      curPass.clear();
      newPass.clear();
      confPass.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    }

    if (mounted) setState(() { passLoading = false; });
  }

  // Restored Continuous HSV 2D Area + Hue Slider + RGB Picker Dialog
  Future<void> _openColorPickerDialog() async {
    final startColor = _parseHexColor(themeHex.text) ?? const Color(0xFF173F35);
    HSVColor hsv = HSVColor.fromColor(startColor);

    final rCtrl = TextEditingController(text: startColor.red.toString());
    final gCtrl = TextEditingController(text: startColor.green.toString());
    final bCtrl = TextEditingController(text: startColor.blue.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setPickerState) {
          final currentColor = hsv.toColor();
          final hexVal = _colorToHex(currentColor);

          void updateFromRgb() {
            final r = int.tryParse(rCtrl.text) ?? currentColor.red;
            final g = int.tryParse(gCtrl.text) ?? currentColor.green;
            final b = int.tryParse(bCtrl.text) ?? currentColor.blue;
            final c = Color.fromARGB(255, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
            setPickerState(() {
              hsv = HSVColor.fromColor(c);
            });
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'Select Theme Color',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF171A1F)),
            ),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Continuous 2D Saturation / Value Canvas Area with Draggable Thumb
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      const height = 170.0;

                      final thumbX = (hsv.saturation * width).clamp(0.0, width);
                      final thumbY = ((1.0 - hsv.value) * height).clamp(0.0, height);

                      return GestureDetector(
                        onPanDown: (details) {
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          final local = box.globalToLocal(details.globalPosition);
                          final sat = (local.dx / width).clamp(0.0, 1.0);
                          final val = 1.0 - (local.dy / height).clamp(0.0, 1.0);
                          setPickerState(() {
                            hsv = hsv.withSaturation(sat).withValue(val);
                            rCtrl.text = hsv.toColor().red.toString();
                            gCtrl.text = hsv.toColor().green.toString();
                            bCtrl.text = hsv.toColor().blue.toString();
                          });
                        },
                        onPanUpdate: (details) {
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          final local = box.globalToLocal(details.globalPosition);
                          final sat = (local.dx / width).clamp(0.0, 1.0);
                          final val = 1.0 - (local.dy / height).clamp(0.0, 1.0);
                          setPickerState(() {
                            hsv = hsv.withSaturation(sat).withValue(val);
                            rCtrl.text = hsv.toColor().red.toString();
                            gCtrl.text = hsv.toColor().green.toString();
                            bCtrl.text = hsv.toColor().blue.toString();
                          });
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: height,
                              width: width,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white,
                                    HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor(),
                                  ],
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black],
                                  ),
                                ),
                              ),
                            ),
                            // Draggable Circular Thumb
                            Positioned(
                              left: (thumbX - 10).clamp(0.0, width - 20),
                              top: (thumbY - 10).clamp(0.0, height - 20),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: currentColor,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Full-Spectrum Rainbow Hue Bar (Matching Website Screenshot 1)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hue', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF747B84))),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final trackWidth = constraints.maxWidth;
                          const trackHeight = 14.0;
                          final thumbX = (hsv.hue / 360.0 * trackWidth).clamp(0.0, trackWidth);

                          void updateHueFromX(double dx) {
                            final newHue = (dx / trackWidth * 360.0).clamp(0.0, 360.0);
                            setPickerState(() {
                              hsv = hsv.withHue(newHue);
                              rCtrl.text = hsv.toColor().red.toString();
                              gCtrl.text = hsv.toColor().green.toString();
                              bCtrl.text = hsv.toColor().blue.toString();
                            });
                          }

                          return GestureDetector(
                            onPanDown: (details) {
                              final RenderBox box = context.findRenderObject() as RenderBox;
                              final local = box.globalToLocal(details.globalPosition);
                              updateHueFromX(local.dx);
                            },
                            onPanUpdate: (details) {
                              final RenderBox box = context.findRenderObject() as RenderBox;
                              final local = box.globalToLocal(details.globalPosition);
                              updateHueFromX(local.dx);
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.centerLeft,
                              children: [
                                // Full-Spectrum Continuous Rainbow Gradient Track
                                Container(
                                  height: trackHeight,
                                  width: trackWidth,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE7E9ED), width: 1),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF0000), // 0° Red
                                        Color(0xFFFFFF00), // 60° Yellow
                                        Color(0xFF00FF00), // 120° Green
                                        Color(0xFF00FFFF), // 180° Cyan
                                        Color(0xFF0000FF), // 240° Blue
                                        Color(0xFFFF00FF), // 300° Magenta
                                        Color(0xFFFF0000), // 360° Red
                                      ],
                                    ),
                                  ),
                                ),
                                // Draggable Circular Thumb
                                Positioned(
                                  left: (thumbX - 10).clamp(0.0, trackWidth - 20),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor(),
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Selected Color Preview + HEX + Editable R, G, B
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7E9ED)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: currentColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE7E9ED), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: currentColor.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hexVal,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF171A1F)),
                                  ),
                                  Text(
                                    'Active Color Preview',
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF747B84)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: rCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => updateFromRgb(),
                                decoration: const InputDecoration(labelText: 'R', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: gCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => updateFromRgb(),
                                decoration: const InputDecoration(labelText: 'G', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: bCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => updateFromRgb(),
                                decoration: const InputDecoration(labelText: 'B', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF747B84))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: AppTheme.onAccentColor,
                ),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      final selectedColor = hsv.toColor();
      final newHex = _colorToHex(selectedColor);
      themeHex.text = newHex;
      themeColorNotifier.value = selectedColor;
      setState(() {});
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
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
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7F9),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Material(
            color: const Color(0xFFF6F7F9),
            child: TabBar(
              isScrollable: true,
              labelColor: AppTheme.accentColor,
              unselectedLabelColor: const Color(0xFF747B84),
              indicatorColor: AppTheme.accentColor,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: [
                Tab(text: loc.translate('Business')),
                Tab(text: loc.translate('Business Rules')),
                Tab(text: loc.translate('Admin Controls')),
                Tab(text: loc.translate('Item Master')),
                Tab(text: loc.translate('Units')),
                Tab(text: loc.translate('Vendors')),
                Tab(text: loc.translate('Expenses')),
              ],
            ),
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE59A2F)))
            : TabBarView(
                children: [
                  _buildBusinessSettings(),
                  _buildBusinessRules(),
                  _buildAdminControls(),
                  _buildItemMaster(),
                  _buildUnitMaster(),
                  _buildVendorMaster(),
                  _buildExpenseCategoryMaster(),
                ],
              ),
      ),
    );
  }

  // 1. Business Profile
  Widget _buildBusinessSettings() {
    final currentColor = _parseHexColor(themeHex.text) ?? const Color(0xFF173F35);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(loc.translate('Business Profile'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
        const SizedBox(height: 16),
        TextField(controller: n, decoration: InputDecoration(labelText: loc.translate('Business Name'))),
        const SizedBox(height: 16),
        TextField(controller: o, decoration: InputDecoration(labelText: loc.translate('Owner Name'))),
        const SizedBox(height: 16),
        TextField(controller: t, decoration: InputDecoration(labelText: loc.translate('Tagline'))),
        const SizedBox(height: 16),
        TextField(controller: c, decoration: InputDecoration(labelText: loc.translate('Currency Symbol'))),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: themeHex,
                decoration: const InputDecoration(labelText: 'Theme Color (HEX e.g. #173F35)'),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Tap to pick theme color',
              child: InkWell(
                onTap: _openColorPickerDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: currentColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE7E9ED), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: currentColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.color_lens_outlined, color: AppTheme.readableForeground(currentColor), size: 22),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: saveBusinessSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentColor,
            foregroundColor: AppTheme.onAccentColor,
            padding: const EdgeInsets.all(16),
          ),
          child: Text(loc.translate('Save Business')),
        ),
      ],
    );
  }

  // 2. Business Rules
  Widget _buildBusinessRules() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Business Rules & Thresholds', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
        const SizedBox(height: 8),
        const Text(
          'Notifications alert when current stock is at or below this low stock threshold amount.',
          style: TextStyle(color: Color(0xFF747B84), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: lst,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Low Stock Alert Threshold (Kg)'),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: saveBusinessRules,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentColor,
            foregroundColor: AppTheme.onAccentColor,
            padding: const EdgeInsets.all(16),
          ),
          child: const Text('Save Business Rules'),
        ),
      ],
    );
  }

  // 3. Admin Controls & Change Password
  Widget _buildAdminControls() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // WhatsApp Send to All Toggle
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE7E9ED))),
          child: SwitchListTile(
            value: whatsappSendAll,
            activeTrackColor: AppTheme.accentColor,
            title: Text('WhatsApp "Send to All"', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF171A1F))),
            subtitle: const Text('Controls availability of bulk WhatsApp reminder feature in Payments & Due.', style: TextStyle(color: Color(0xFF747B84), fontSize: 12)),
            onChanged: toggleWhatsAppSendAll,
          ),
        ),
        const SizedBox(height: 24),

        // Change Password Section
        Text(loc.translate('Change Admin Password'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
        const SizedBox(height: 8),
        Text(loc.translate('Update your password to keep your business data secure.'), style: const TextStyle(color: Color(0xFF747B84), fontSize: 13)),
        const SizedBox(height: 20),
        TextField(
          controller: curPass,
          obscureText: _hideCurPass,
          decoration: InputDecoration(
            labelText: loc.translate('Current Password'),
            suffixIcon: IconButton(
              icon: Icon(_hideCurPass ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF747B84)),
              onPressed: () => setState(() => _hideCurPass = !_hideCurPass),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: newPass,
          obscureText: _hideNewPass,
          decoration: InputDecoration(
            labelText: loc.translate('New Password'),
            suffixIcon: IconButton(
              icon: Icon(_hideNewPass ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF747B84)),
              onPressed: () => setState(() => _hideNewPass = !_hideNewPass),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: confPass,
          obscureText: _hideConfPass,
          decoration: InputDecoration(
            labelText: loc.translate('Confirm New Password'),
            suffixIcon: IconButton(
              icon: Icon(_hideConfPass ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF747B84)),
              onPressed: () => setState(() => _hideConfPass = !_hideConfPass),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: passLoading ? null : _changePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentColor,
            foregroundColor: AppTheme.onAccentColor,
            disabledBackgroundColor: const Color(0xFFE7E9ED),
            disabledForegroundColor: const Color(0xFF747B84),
            padding: const EdgeInsets.all(16),
          ),
          child: passLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppTheme.onAccentColor,
                    strokeWidth: 2,
                  ),
                )
              : Text(loc.translate('Changing...').replaceAll('...', '') == 'Changing' ? 'Change Password' : loc.translate('update password')),
        ),
      ],
    );
  }

  // 4. Item Master
  Widget _buildItemMaster() {
    final items = masters?['items'] as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: Text(loc.translate('Vegetable / Item Master'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)))),
            ElevatedButton.icon(
              onPressed: () => _addItemDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(loc.translate('add item')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.onAccentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...items.map((i) {
          final String nameEn = (i['name_en'] ?? i['nameEn'] ?? 'Unknown').toString();
          final String nameHi = (i['name_hi'] ?? i['nameHi'] ?? '').toString();
          final String primaryName = loc.isHindi && nameHi.isNotEmpty ? nameHi : nameEn;
          final specsList = (i['specifications'] as List?) ?? [];
          final bool hasHistory = i['has_history'] == true || i['hasHistory'] == true;

          return Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE7E9ED))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(primaryName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF171A1F))),
                            if (nameHi.isNotEmpty && !loc.isHindi)
                              Text(nameHi, style: const TextStyle(color: Color(0xFF747B84), fontSize: 12)),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _addSpecDialog(i['id'].toString(), primaryName),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Spec', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: i['active'] ?? true,
                        activeTrackColor: AppTheme.accentColor,
                        onChanged: (v) async {
                          setState(() { i['active'] = v; });
                          try {
                            await widget.api.updateItemMaster(i['id'].toString(), {'active': v});
                          } catch (e) {
                            setState(() { i['active'] = !v; });
                          }
                        },
                      ),
                      if (!hasHistory)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteItem(i['id'].toString(), primaryName),
                        ),
                    ],
                  ),
                  if (specsList.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: specsList.map((s) {
                        final specName = (s['name'] ?? '').toString();
                        final specId = s['id']?.toString() ?? '';
                        return Chip(
                          label: Text(specName, style: const TextStyle(fontSize: 11)),
                          backgroundColor: const Color(0xFFF6F7F9),
                          onDeleted: specId.isNotEmpty
                              ? () async {
                                  try {
                                    await widget.api.removeSpecification(specId);
                                    load();
                                  } catch (_) {}
                                }
                              : null,
                          deleteIconColor: Colors.redAccent,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addItemDialog() async {
    final en = TextEditingController();
    final hi = TextEditingController();
    final specs = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.translate('add item'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: en, decoration: const InputDecoration(labelText: 'English Name * (e.g. Capsicum)')),
            const SizedBox(height: 12),
            TextField(controller: hi, decoration: const InputDecoration(labelText: 'Hindi Name (e.g. शिमला मिर्च)')),
            const SizedBox(height: 12),
            TextField(controller: specs, decoration: const InputDecoration(labelText: 'Initial Specifications (comma separated, e.g. Grade A, Medium)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(loc.translate('cancel'), style: const TextStyle(color: Color(0xFF747B84)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: AppTheme.onAccentColor,
            ),
            child: Text(loc.translate('add')),
          ),
        ],
      ),
    );

    if (ok == true && en.text.trim().isNotEmpty) {
      final specList = specs.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      await widget.api.create('masters/items', {
        'name_en': en.text.trim(),
        'name_hi': hi.text.trim(),
        'specifications': specList,
      });
      load();
    }
  }

  Future<void> _addSpecDialog(String itemId, String itemName) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('+ Specification for $itemName', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF171A1F))),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Specification Name (e.g. Medium, Grade A)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(loc.translate('cancel'), style: const TextStyle(color: Color(0xFF747B84)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: AppTheme.onAccentColor,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty && itemId.isNotEmpty) {
      await widget.api.addItemSpecification(itemId, controller.text.trim());
      load();
    }
  }

  Future<void> _deleteItem(String itemId, String itemName) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $itemName?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
        content: const Text('Permanent delete is only allowed for items with no transaction history.', style: TextStyle(color: Color(0xFF747B84))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(loc.translate('cancel'), style: const TextStyle(color: Color(0xFF747B84)))),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) {
      try {
        await widget.api.remove('masters/items', itemId);
        load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e'), backgroundColor: Colors.redAccent));
        }
      }
    }
  }

  // 5. Unit Master
  Widget _buildUnitMaster() {
    final list = masters?['units'] as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: Text('Quantity Unit Master', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)))),
            ElevatedButton.icon(
              onPressed: () => _addUnitDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Unit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.onAccentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...list.map((i) {
          final String name = (i['name'] ?? '').toString();
          final String symbol = (i['symbol'] ?? name).toString();
          final num kg = i['kg_multiplier'] ?? i['kgMultiplier'] ?? 1;

          return Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE7E9ED))),
            child: ListTile(
              title: Text('$name ($symbol)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
              subtitle: Text('1 $symbol = $kg Kg', style: const TextStyle(color: Color(0xFFE59A2F), fontWeight: FontWeight.bold, fontSize: 13)),
              trailing: Switch(
                value: i['active'] ?? true,
                activeTrackColor: AppTheme.accentColor,
                onChanged: (v) async {
                  setState(() { i['active'] = v; });
                  try {
                    await widget.api.update('masters/units', i['id'], {'active': v});
                  } catch (e) {
                    setState(() { i['active'] = !v; });
                  }
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addUnitDialog() async {
    final nameCtrl = TextEditingController();
    final symbolCtrl = TextEditingController();
    final kgCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Quantity Unit', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Unit Name (e.g. Quintal)')),
            const SizedBox(height: 12),
            TextField(controller: symbolCtrl, decoration: const InputDecoration(labelText: 'Symbol (e.g. Qtl)')),
            const SizedBox(height: 12),
            TextField(controller: kgCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '1 Unit = ? Kg (e.g. 100)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(loc.translate('cancel'), style: const TextStyle(color: Color(0xFF747B84)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: AppTheme.onAccentColor,
            ),
            child: Text(loc.translate('add')),
          ),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await widget.api.create('masters/units', {
        'name': nameCtrl.text.trim(),
        'symbol': symbolCtrl.text.trim().isEmpty ? nameCtrl.text.trim() : symbolCtrl.text.trim(),
        'kg_multiplier': num.tryParse(kgCtrl.text.trim()) ?? 1,
      });
      load();
    }
  }

  // 6. Vendor Master
  Widget _buildVendorMaster() {
    final list = masters?['vendors'] as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: Text('Vendor / Supplier Master', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)))),
            ElevatedButton.icon(
              onPressed: () => _addVendorDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Vendor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.onAccentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...list.map((i) {
          final String name = (i['name'] ?? '').toString();
          final String type = (i['vendor_type'] ?? i['type'] ?? 'Both').toString();

          return Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE7E9ED))),
            child: ListTile(
              title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
              subtitle: Text('$name · $type', style: const TextStyle(color: Color(0xFF747B84), fontSize: 12)),
              trailing: Switch(
                value: i['active'] ?? true,
                activeTrackColor: AppTheme.accentColor,
                onChanged: (v) async {
                  setState(() { i['active'] = v; });
                  try {
                    await widget.api.update('masters/vendors', i['id'], {'active': v});
                  } catch (e) {
                    setState(() { i['active'] = !v; });
                  }
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addVendorDialog() async {
    final nameCtrl = TextEditingController();
    String vendorType = 'Both';

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add Vendor / Mandi', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Vendor / Mandi Name *')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: vendorType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'Mandi', child: Text('Mandi')),
                  DropdownMenuItem(value: 'Local', child: Text('Local')),
                  DropdownMenuItem(value: 'Both', child: Text('Both')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => vendorType = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(loc.translate('cancel'), style: const TextStyle(color: Color(0xFF747B84)))),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.onAccentColor,
              ),
              child: Text(loc.translate('add')),
            ),
          ],
        ),
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await widget.api.create('masters/vendors', {
        'name': nameCtrl.text.trim(),
        'vendor_type': vendorType,
      });
      load();
    }
  }

  // 7. Expense Category Master
  Widget _buildExpenseCategoryMaster() {
    final list = masters?['expenseCategories'] as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: Text('Expense Category Master', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)))),
            ElevatedButton.icon(
              onPressed: () => _addExpenseCategoryDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.onAccentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...list.map((i) {
          final String name = (i['name'] ?? '').toString();

          return Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE7E9ED))),
            child: ListTile(
              title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
              trailing: Switch(
                value: i['active'] ?? true,
                activeTrackColor: AppTheme.accentColor,
                onChanged: (v) async {
                  setState(() { i['active'] = v; });
                  try {
                    await widget.api.update('masters/expense-categories', i['id'], {'active': v});
                  } catch (e) {
                    setState(() { i['active'] = !v; });
                  }
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addExpenseCategoryDialog() async {
    final nameCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Expense Category', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name (e.g. Fuel, Transport)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(loc.translate('cancel'), style: const TextStyle(color: Color(0xFF747B84)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: AppTheme.onAccentColor,
            ),
            child: Text(loc.translate('add')),
          ),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await widget.api.create('masters/expense-categories', {
        'name': nameCtrl.text.trim(),
      });
      load();
    }
  }
}
