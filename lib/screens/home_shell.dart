import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app.dart';
import '../core/api_client.dart';
import '../core/resource_config.dart';
import '../core/localization.dart';
import '../widgets/resource_page.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'backup_screen.dart';
import 'login_screen.dart';

class HomeShell extends StatefulWidget {
  final ApiClient api;
  const HomeShell({super.key, required this.api});
  @override
  State<HomeShell> createState() => _S();
}

class _S extends State<HomeShell> {
  final loc = Localization();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int index = 0;
  bool _isExitDialogShowing = false;

  List<({String title, IconData icon, String? resource})> get nav => [
    (title: loc.translate('dashboard'), icon: Icons.dashboard_outlined, resource: null),
    (title: loc.translate('mandi purchase'), icon: Icons.shopping_basket_outlined, resource: 'mandi-purchases'),
    (title: loc.translate('local purchase'), icon: Icons.store_outlined, resource: 'local-purchases'),
    (title: loc.translate('stock / inventory'), icon: Icons.inventory_2_outlined, resource: 'stock'),
    (title: loc.translate('sales / supply'), icon: Icons.local_shipping_outlined, resource: 'sales'),
    (title: loc.translate('customers'), icon: Icons.people_outline, resource: 'customers'),
    (title: loc.translate('payments & due'), icon: Icons.account_balance_wallet_outlined, resource: 'payments'),
    (title: loc.translate('expenses'), icon: Icons.receipt_long_outlined, resource: 'expenses'),
    (title: loc.translate('labour / majdoor'), icon: Icons.engineering_outlined, resource: 'labour'),
    (title: loc.translate('reports & analytics'), icon: Icons.bar_chart_outlined, resource: 'reports'),
    (title: loc.translate('whatsapp bills'), icon: Icons.message_outlined, resource: 'whatsapp-bills'),
    (title: loc.translate('notifications'), icon: Icons.notifications_none, resource: 'notifications'),
    (title: loc.translate('settings'), icon: Icons.settings_outlined, resource: null),
    (title: loc.translate('backup / export'), icon: Icons.backup_outlined, resource: 'backup')
  ];

  Widget page() {
    final items = [
      'dashboard', 'mandi-purchases', 'local-purchases', 'stock',
      'sales', 'customers', 'payments', 'expenses', 'labour', 'reports', 'whatsapp-bills',
      'notifications', 'settings', 'backup'
    ];
    final key = items[index];

    if (index == 0) {
      return DashboardScreen(
        api: widget.api,
        onViewNotifications: () {
          final i = items.indexOf('notifications');
          if (i != -1) setState(() => index = i);
        },
      );
    }
    if (key == 'reports') return ReportsScreen(api: widget.api);
    if (key == 'backup') return BackupScreen(api: widget.api);
    if (key == 'settings') return SettingsScreen(api: widget.api);

    final def = resources[key];
    if (def != null) {
      return ResourcePage(
        key: ValueKey('resource_$key'),
        def: def,
        api: widget.api,
        isHindi: loc.isHindi,
      );
    }

    return const Center(child: Text('Module under construction'));
  }

  Future<void> _showExitConfirmationDialog() async {
    if (_isExitDialogShowing) return;
    _isExitDialogShowing = true;

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Exit SabziSetu?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF171A1F)),
        ),
        content: const Text(
          'Are you sure you want to exit the app?',
          style: TextStyle(color: Color(0xFF747B84), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              loc.translate('cancel'),
              style: const TextStyle(color: Color(0xFF747B84), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: AppTheme.onAccentColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Exit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    _isExitDialogShowing = false;

    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  Future<void> _showGlobalSearchDialog() async {
    final items = [
      'dashboard', 'mandi-purchases', 'local-purchases', 'stock',
      'sales', 'customers', 'payments', 'expenses', 'labour', 'reports', 'whatsapp-bills',
      'notifications', 'settings', 'backup'
    ];
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final q = controller.text.trim().toLowerCase();

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Global Business Search', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF171A1F))),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search customers, items, bills, vendors...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFE59A2F)),
                      suffixIcon: q.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setDialogState(() => controller.clear()))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (q.isNotEmpty)
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _searchGlobal(q),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFFE59A2F)));
                        }
                        final results = snapshot.data ?? [];
                        if (results.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('No matches for "$q".', style: const TextStyle(color: Color(0xFF747B84))),
                          );
                        }
                        return SizedBox(
                          height: 260,
                          child: ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (c, i) {
                              final r = results[i];
                              final String targetModule = r['module']?.toString() ?? 'dashboard';
                              final String title = r['title']?.toString() ?? 'Record';
                              final String subtitle = r['sub']?.toString() ?? '';

                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.inventory_2_outlined, color: Color(0xFFE59A2F), size: 18),
                                title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF171A1F))),
                                subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF747B84))),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  final idx = items.indexOf(targetModule);
                                  if (idx != -1) {
                                    setState(() { index = idx; });
                                  }
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(loc.translate('cancel'), style: const TextStyle(color: Color(0xFF747B84))),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _searchGlobal(String query) async {
    final results = <Map<String, dynamic>>[];
    try {
      final res = await Future.wait([
        widget.api.list('customers'),
        widget.api.list('stock'),
        widget.api.list('sales'),
        widget.api.list('mandi-purchases'),
      ]);

      final customers = res[0];
      for (final c in customers) {
        final name = c['name']?.toString() ?? '';
        if (name.toLowerCase().contains(query)) {
          results.add({'module': 'customers', 'title': name, 'sub': 'Customer · Due ₹${c['due'] ?? 0}'});
        }
      }

      final stock = res[1];
      for (final s in stock) {
        final item = s['item']?.toString() ?? '';
        if (item.toLowerCase().contains(query)) {
          results.add({'module': 'stock', 'title': item, 'sub': 'Stock · ${s['qty'] ?? 0} Kg on hand'});
        }
      }

      final sales = res[2];
      for (final s in sales) {
        final item = s['item']?.toString() ?? '';
        final cust = s['customer']?.toString() ?? '';
        if (item.toLowerCase().contains(query) || cust.toLowerCase().contains(query)) {
          results.add({'module': 'sales', 'title': '$item — $cust', 'sub': 'Sale · ₹${s['amount'] ?? 0}'});
        }
      }

      final mandi = res[3];
      for (final p in mandi) {
        final item = p['item']?.toString() ?? '';
        final vendor = p['vendor']?.toString() ?? '';
        if (item.toLowerCase().contains(query) || vendor.toLowerCase().contains(query)) {
          results.add({'module': 'mandi-purchases', 'title': '$item — $vendor', 'sub': 'Mandi Purchase · ${p['date'] ?? ''}'});
        }
      }
    } catch (_) {}
    return results;
  }

  @override
  Widget build(BuildContext c) => LayoutBuilder(builder: (c, b) {
        final wide = b.maxWidth >= 1024;
        final content = page();
        final accent = AppTheme.accentColor;
        
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (didPop) return;

            // 1. If side drawer is open, close it
            if (_scaffoldKey.currentState?.isDrawerOpen == true) {
              _scaffoldKey.currentState?.closeDrawer();
              return;
            }

            // 2. If on any page other than Dashboard (index != 0), switch to Dashboard
            if (index != 0) {
              setState(() {
                index = 0;
              });
              return;
            }

            // 3. If on Dashboard root (index == 0), show Theme-Aware Exit Confirmation Dialog
            await _showExitConfirmationDialog();
          },
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: const Color(0xFFF6F7F9),
            appBar: wide
                ? null
                : AppBar(
                    backgroundColor: const Color(0xFFF6F7F9),
                    elevation: 0,
                    iconTheme: IconThemeData(color: accent),
                    title: Text(
                      nav[index].title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF171A1F),
                        fontSize: 18,
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.search_rounded),
                        tooltip: 'Global Search',
                        onPressed: _showGlobalSearchDialog,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: TextButton(
                          onPressed: () => loc.toggleLanguage(),
                          style: TextButton.styleFrom(
                            backgroundColor: AppTheme.accentSoft,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text(
                            loc.isHindi ? 'EN' : 'हिं',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: accent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
            drawer: wide ? null : Drawer(child: _sidebar('drawer')),
            body: Row(children: [
              if (wide) SizedBox(width: 280, child: _sidebar('sidebar')),
              Expanded(child: content)
            ]),
          ),
        );
      });

  Widget _sidebar(String position) => SidebarWidget(
        nav: nav,
        index: index,
        isHindi: loc.isHindi,
        onTap: (i) {
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            Navigator.pop(context);
          }
          if (index != i) {
            setState(() => index = i);
          }
        },
        onToggleLang: () => loc.toggleLanguage(),
        onLogout: () async {
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            Navigator.pop(context);
          }
          await widget.api.logout();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (c) => LoginScreen(api: widget.api)),
              (route) => false,
            );
          }
        },
        showLang: position == 'sidebar',
      );
}

class SidebarWidget extends StatelessWidget {
  final List<({String title, IconData icon, String? resource})> nav;
  final int index;
  final bool isHindi;
  final Function(int) onTap;
  final VoidCallback onToggleLang;
  final VoidCallback onLogout;
  final bool showLang;

  const SidebarWidget({
    super.key,
    required this.nav,
    required this.index,
    required this.isHindi,
    required this.onTap,
    required this.onToggleLang,
    required this.onLogout,
    required this.showLang,
  });

  @override
  Widget build(BuildContext context) {
    final loc = Localization();
    final accent = AppTheme.accentColor;
    final accentSoft = AppTheme.accentSoft;

    return Material(
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Color(0xFFE7E9ED))),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: accentSoft, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.eco_rounded, color: accent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SabziSetu', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF171A1F))),
                            Text('Smart Trading', style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE7E9ED)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                itemCount: nav.length,
                itemBuilder: (context, i) {
                  final item = nav[i];
                  final isSelected = index == i;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? accentSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(item.icon, color: isSelected ? accent : const Color(0xFF747B84), size: 20),
                      title: Text(
                        item.title,
                        style: GoogleFonts.poppins(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? accent : const Color(0xFF171A1F),
                          fontSize: 13,
                        ),
                      ),
                      onTap: () => onTap(i),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE7E9ED)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (showLang)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.language_rounded, color: Color(0xFF747B84), size: 20),
                      title: Text(isHindi ? 'English' : 'हिंदी', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                      onTap: onToggleLang,
                    ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    title: Text(loc.translate('logout'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13)),
                    onTap: onLogout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
