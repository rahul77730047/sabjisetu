import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../app.dart';
import '../core/api_client.dart';
import '../core/resource_config.dart';
import '../core/localization.dart';

class ResourcePage extends StatefulWidget {
  const ResourcePage({
    super.key,
    required this.def,
    required this.api,
    this.isHindi = false,
  });

  final ResourceDef def;
  final ApiClient api;
  final bool isHindi;

  @override
  State<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends State<ResourcePage> {
  final loc = Localization();
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> filteredRows = [];
  List<Map<String, dynamic>> customersList = [];

  bool loading = true;
  String? error;
  Map<String, dynamic>? masters;

  // Filter controllers
  final TextEditingController searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showExpandedHeader = true;

  DateTime? dateFrom;
  DateTime? dateTo;
  String? selectedStatus;
  String? selectedType;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    load();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final userScrollDirection = _scrollController.position.userScrollDirection;
    if (userScrollDirection == ScrollDirection.reverse) {
      if (_showExpandedHeader && _scrollController.offset > 20) {
        setState(() {
          _showExpandedHeader = false;
        });
      }
    } else if (userScrollDirection == ScrollDirection.forward || _scrollController.offset <= 10) {
      if (!_showExpandedHeader) {
        setState(() {
          _showExpandedHeader = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant ResourcePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.def.id != widget.def.id || oldWidget.isHindi != widget.isHindi) {
      _clearFilters();
      load();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final futures = <Future<dynamic>>[
        widget.api.list(widget.def.id),
        widget.api.masters(),
      ];
      if (widget.def.id == 'payments') {
        futures.add(widget.api.list('customers'));
      }

      final res = await Future.wait(futures);
      if (!mounted) return;
      rows = List<Map<String, dynamic>>.from(res[0] as Iterable);
      masters = res[1] as Map<String, dynamic>;

      if (widget.def.id == 'payments' && res.length > 2) {
        customersList = List<Map<String, dynamic>>.from(res[2] as Iterable);
      }

      _applyFilters();
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); });
    }
    if (mounted) setState(() { loading = false; });
  }

  void _clearFilters() {
    searchCtrl.clear();
    dateFrom = null;
    dateTo = null;
    selectedStatus = null;
    selectedType = null;
    _applyFilters();
  }

  void _applyFilters() {
    final query = searchCtrl.text.trim().toLowerCase();
    if (!mounted) return;

    setState(() {
      filteredRows = rows.where((row) {
        // Search query filter
        if (query.isNotEmpty) {
          final matches = row.values.any((v) => v.toString().toLowerCase().contains(query));
          if (!matches) return false;
        }

        // Date Range filter (Bypassed for perpetual stock snapshot)
        if (widget.def.id != 'stock' && widget.def.id != 'notifications' && widget.def.id != 'whatsapp-bills') {
          final dateStr = row['date']?.toString() ?? row['movement_date']?.toString() ?? row['created_at']?.toString();
          if (dateStr != null && dateStr.isNotEmpty) {
            final rowDate = DateTime.tryParse(dateStr.substring(0, 10));
            if (rowDate != null) {
              if (dateFrom != null && rowDate.isBefore(dateFrom!)) return false;
              if (dateTo != null && rowDate.isAfter(dateTo!.add(const Duration(days: 1)))) return false;
            }
          }
        }

        // Status Filter
        if (selectedStatus != null && selectedStatus!.isNotEmpty) {
          final rowStatus = row['status']?.toString() ?? '';
          if (rowStatus.toLowerCase() != selectedStatus!.toLowerCase()) return false;
        }

        // Type Filter
        if (selectedType != null && selectedType!.isNotEmpty) {
          final rowType = row['kind']?.toString() ?? row['type']?.toString() ?? '';
          if (rowType.toLowerCase() != selectedType!.toLowerCase()) return false;
        }

        return true;
      }).toList();
    });
  }

  double _number(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0.0;
  }

  String _money(dynamic value) {
    final number = _number(value);
    if (number == number.roundToDouble()) return '₹${number.toStringAsFixed(0)}';
    return '₹${number.toStringAsFixed(2)}';
  }

  String showValue(String key, dynamic value) {
    if (value == null) return '—';
    if (key == 'avg_cost' || key == 'avgCost' || key == 'selling_price' || key == 'sellingPrice' || key == 'rate' || key == 'amount') {
      return _money(value);
    }
    if (key == 'qty' || key == 'quantity_value' || key == 'quantityValue') {
      final n = double.tryParse(value.toString()) ?? 0;
      return '${n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2)} Kg';
    }
    if (key == 'qty_change') {
      final n = double.tryParse(value.toString()) ?? 0;
      return '${n > 0 ? '+' : ''}$n Kg';
    }
    if (loc.isHindi && key == 'item') {
      final items = masters?['items'];
      if (items is List) {
        for (final rawItem in items) {
          if (rawItem is Map) {
            final english = rawItem['nameEn']?.toString() ?? rawItem['name_en']?.toString() ?? '';
            if (english == value.toString()) {
              final hindi = rawItem['nameHi']?.toString() ?? rawItem['name_hi']?.toString() ?? '';
              if (hindi.trim().isNotEmpty) return hindi;
            }
          }
        }
      }
    }
    return value.toString();
  }

  bool _usesMasterSuggestions(String key) => key == 'item' || key == 'vendor' || key == 'quantity_unit' || key == 'category' || key == 'customer';

  List<String> _masterOptions(String key) {
    final values = <String>[];
    if (key == 'item') {
      final data = masters?['items'];
      if (data is List) { for (final raw in data) { if (raw is Map && (raw['active'] == true || raw['active'] == null)) { values.add(raw['nameEn']?.toString() ?? raw['name_en']?.toString() ?? ''); } } }
    } else if (key == 'vendor') {
      final data = masters?['vendors'];
      if (data is List) { for (final raw in data) { if (raw is Map && (raw['active'] == true || raw['active'] == null)) { values.add(raw['name']?.toString() ?? ''); } } }
    } else if (key == 'quantity_unit') {
      final data = masters?['units'];
      if (data is List) { for (final raw in data) { if (raw is Map && (raw['active'] == true || raw['active'] == null)) { values.add(raw['symbol']?.toString() ?? ''); } } }
    } else if (key == 'category') {
      final data = masters?['expenseCategories'];
      if (data is List) { for (final raw in data) { if (raw is Map && (raw['active'] == true || raw['active'] == null)) { values.add(raw['name']?.toString() ?? ''); } } }
    } else if (key == 'customer') {
      final data = masters?['customers'];
      if (data is List) { for (final raw in data) { if (raw is Map) { values.add(raw['name']?.toString() ?? ''); } } }
    }
    final unique = values.where((v) => v.isNotEmpty).toSet().toList();
    unique.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return unique;
  }

  Future<void> showForm([Map<String, dynamic>? existing]) async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (c) => _ResourceFormDialog(
        def: widget.def, existing: existing, masters: masters, translate: loc.translate, masterOptions: _masterOptions, usesMasterSuggestions: _usesMasterSuggestions,
      ),
    );
    if (result == null || !mounted) return;

    try {
      if (existing != null) {
        if (result is Map<String, dynamic>) {
          await widget.api.update(widget.def.id, existing['id'].toString(), result);
        }
      } else {
        if (result is List<Map<String, dynamic>>) {
          for (final itemPayload in result) {
            await widget.api.create(widget.def.id, itemPayload);
          }
        } else if (result is Map<String, dynamic>) {
          await widget.api.create(widget.def.id, result);
        }
      }
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate(existing != null ? 'update' : 'save'))));
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.startsWith('Exception: ')) msg = msg.replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> del(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;

    // First call backend safety check
    final check = await widget.api.checkDelete(widget.def.id, id);
    if (check['canDelete'] == false) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.orangeAccent),
              const SizedBox(width: 10),
              Text('Deletion Blocked', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
            ],
          ),
          content: Text(
            check['reason']?.toString() ?? 'Cannot delete this record because linked transaction history exists.',
            style: const TextStyle(color: Color(0xFF747B84)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('OK', style: TextStyle(color: Color(0xFF20252B), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.translate('delete entry'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
        content: Text(loc.translate('are you sure'), style: const TextStyle(color: Color(0xFF747B84))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(loc.translate('cancel'), style: const TextStyle(color: Color(0xFF747B84)))),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), child: Text(loc.translate('delete'))),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.api.remove(widget.def.id, id);
      await load();
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.startsWith('Exception: ')) msg = msg.replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: Color(0xFFE59A2F)));
    if (error != null) {
      String displayErr = error!;
      if (displayErr.contains('<!DOCTYPE html>') || displayErr.contains('Cannot GET')) {
        displayErr = 'Unable to load stock history. Please try again.';
      } else {
        displayErr = displayErr.replaceAll('Exception: ', '').trim();
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Color(0xFF747B84)),
              const SizedBox(height: 12),
              Text(displayErr, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF171A1F), fontSize: 14)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: load,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: AppTheme.onAccentColor,
                ),
                child: Text(loc.translate('retry')),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      return Column(children: [
        AnimatedCrossFade(
          firstChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopBar(context),
              _buildSummaryCards(),
            ],
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _showExpandedHeader ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 250),
        ),
        _buildFilterBar(),
        Expanded(child: RefreshIndicator(
          onRefresh: load,
          color: const Color(0xFFE59A2F),
          child: AnimationLimiter(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (widget.def.id == 'payments')
                  _buildPaymentsLayout()
                else if (filteredRows.isEmpty)
                  Padding(padding: const EdgeInsets.only(top: 100), child: Center(child: Text(loc.translate('no records found'), style: const TextStyle(color: Color(0xFF747B84)))))
                else
                  isWide ? _buildTable() : _buildCards(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        )),
      ]);
    });
  }

  Widget _buildTopBar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(
            loc.translate(widget.def.title),
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
          ),
        ),
        if (widget.def.id == 'notifications')
          TextButton.icon(
            onPressed: () async {
              await widget.api.markAllNotificationsRead();
              await load();
            },
            icon: const Icon(Icons.done_all, size: 18, color: Color(0xFFE59A2F)),
            label: const Text('Mark All Read', style: TextStyle(color: Color(0xFFE59A2F), fontWeight: FontWeight.bold)),
          ),
        if (widget.def.fields.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () => showForm(),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(loc.translate('add')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20252B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
      ],
    ),
  );

  Widget _buildSummaryCards() {
    if (filteredRows.isEmpty && widget.def.id != 'payments') return const SizedBox.shrink();

    // Module-Specific Summary Card Handling
    if (widget.def.id == 'notifications' || widget.def.id == 'whatsapp-bills') {
      return const SizedBox.shrink();
    }

    double totalAmount = 0.0;
    double totalQty = 0.0;

    for (final r in filteredRows) {
      totalAmount += _number(r['amount'] ?? r['selling_price']);
      totalQty += _number(r['qty'] ?? r['quantity_value']);
    }

    if (widget.def.id == 'expenses') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            Expanded(child: _summaryTile('Total Expenses', _money(totalAmount), Icons.receipt_long_outlined, Colors.redAccent)),
          ],
        ),
      );
    }

    if (widget.def.id == 'labour') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            Expanded(child: _summaryTile('Total Labour Cost', _money(totalAmount), Icons.engineering_outlined, const Color(0xFF20252B))),
          ],
        ),
      );
    }

    final double avgRate = totalQty > 0 ? (totalAmount / totalQty) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(child: _summaryTile('Total Value', _money(totalAmount), Icons.account_balance_wallet_outlined, const Color(0xFF20252B))),
          const SizedBox(width: 12),
          Expanded(child: _summaryTile('Total Qty', '${totalQty.toStringAsFixed(1)} Kg', Icons.scale_outlined, const Color(0xFFE59A2F))),
          const SizedBox(width: 12),
          Expanded(child: _summaryTile('Avg Rate', _money(avgRate), Icons.analytics_outlined, const Color(0xFF4F8A68))),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E9ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF747B84)), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // ALWAYS VISIBLE SEARCH BAR
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7E9ED)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: TextField(
              controller: searchCtrl,
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: '${loc.translate('search')}...',
                hintStyle: const TextStyle(color: Color(0xFF747B84)),
                prefixIcon: const Icon(Icons.search_rounded, size: 22, color: Color(0xFFE59A2F)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
          // COLLAPSIBLE DATE FILTERS ON SCROLL
          AnimatedCrossFade(
            firstChild: Column(
              children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dateFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() { dateFrom = picked; });
                            _applyFilters();
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFFE59A2F)),
                        label: Text(dateFrom == null ? 'From Date' : dateFrom!.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 12, color: Color(0xFF171A1F))),
                        style: TextButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE7E9ED)))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dateTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() { dateTo = picked; });
                            _applyFilters();
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFFE59A2F)),
                        label: Text(dateTo == null ? 'To Date' : dateTo!.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 12, color: Color(0xFF171A1F))),
                        style: TextButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE7E9ED)))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _clearFilters,
                      style: TextButton.styleFrom(backgroundColor: const Color(0xFFFFF4E2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Clear', style: TextStyle(color: Color(0xFFE59A2F), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _showExpandedHeader ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // Dedicated Payments & Due Structured Layout
  Widget _buildPaymentsLayout() {
    final query = searchCtrl.text.trim().toLowerCase();

    // Filter customers with outstanding due > 0
    final dueCustomers = customersList.where((c) {
      final d = _number(c['due']);
      if (d <= 0) return false;
      if (query.isNotEmpty) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final phone = (c['phone'] ?? '').toString().toLowerCase();
        return name.contains(query) || phone.contains(query);
      }
      return true;
    }).toList();

    // Filter payment history transactions (type == 'Payment')
    final paymentHistory = filteredRows.where((r) => r['type'] == 'Payment').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION 1: OUTSTANDING DUES
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Color(0xFFE59A2F)),
              const SizedBox(width: 8),
              Text(
                'Outstanding Dues',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFFF4E2), borderRadius: BorderRadius.circular(10)),
                child: Text('${dueCustomers.length}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFE59A2F))),
              ),
            ],
          ),
        ),
        if (dueCustomers.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE7E9ED))),
            child: const Center(child: Text('No outstanding dues.', style: TextStyle(color: Color(0xFF747B84), fontSize: 13))),
          )
        else
          ...dueCustomers.map((c) => _dueCustomerCard(c)),

        const SizedBox(height: 16),

        // SECTION 2: PAYMENT HISTORY
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.history_outlined, size: 20, color: Color(0xFF20252B)),
              const SizedBox(width: 8),
              Text(
                'Payment History',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF6F7F9), borderRadius: BorderRadius.circular(10)),
                child: Text('${paymentHistory.length}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF20252B))),
              ),
            ],
          ),
        ),
        if (paymentHistory.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE7E9ED))),
            child: const Center(child: Text('No payment history available.', style: TextStyle(color: Color(0xFF747B84), fontSize: 13))),
          )
        else
          ...paymentHistory.map((p) => _paymentHistoryCard(p)),
      ],
    );
  }

  Widget _dueCustomerCard(Map<String, dynamic> c) {
    final name = c['name']?.toString() ?? 'Customer';
    final dueVal = _money(c['due']);
    final phone = c['phone']?.toString() ?? '';
    final status = c['status']?.toString() ?? 'Due';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E9ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dueVal,
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statusBadge(status),
              if (phone.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF747B84)),
                const SizedBox(width: 4),
                Text(phone, style: const TextStyle(fontSize: 13, color: Color(0xFF747B84), fontWeight: FontWeight.w500)),
              ],
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Divider(height: 1, color: Color(0xFFE7E9ED)),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _sendWhatsApp({
                'customer': name,
                'phone': phone,
                'amount': c['due'],
                'type': 'Due',
                'date': c['due_date'] ?? '',
              }),
              icon: const Icon(Icons.message_outlined, size: 16),
              label: const Text('Send WhatsApp Reminder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F8A68),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentHistoryCard(Map<String, dynamic> p) {
    final dateVal = showValue('date', p['date']);
    final name = p['customer']?.toString() ?? 'Customer';
    final amountVal = showValue('amount', p['amount']);
    final method = p['payment_method']?.toString() ?? 'Cash';
    final note = p['note']?.toString() ?? '';
    final proofStr = (p['payment_proof'] ?? p['paymentProof'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E9ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE59A2F).withValues(alpha: 0.3)),
                ),
                child: Text(
                  dateVal,
                  style: GoogleFonts.poppins(color: const Color(0xFFE59A2F), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                amountVal,
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF4F8A68)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE7E9ED)),
                ),
                child: Text(
                  method.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF20252B)),
                ),
              ),
              if (note.isNotEmpty && note != '—') ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Note: $note',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF747B84)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Divider(height: 1, color: Color(0xFFE7E9ED)),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (proofStr.isNotEmpty)
                  _actionBtn(onTap: () => _showProofDialog(proofStr), icon: Icons.image_outlined, label: 'View Proof', color: const Color(0xFFE59A2F)),
                _actionBtn(onTap: () => showForm(p), icon: Icons.edit_outlined, label: loc.translate('edit'), color: const Color(0xFF4B5563)),
                _actionBtn(onTap: () => del(p), icon: Icons.delete_outline, label: loc.translate('delete'), color: Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() => AnimationLimiter(
    child: Column(
      children: AnimationConfiguration.toStaggeredList(
        duration: const Duration(milliseconds: 375),
        childAnimationBuilder: (w) => SlideAnimation(horizontalOffset: 50.0, child: FadeInAnimation(child: w)),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE7E9ED))),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFFFF4E2)),
              columns: [...widget.def.columns.map((k) => DataColumn(label: Text(loc.translate(k), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF20252B))))), DataColumn(label: Text(loc.translate('Actions')))],
              rows: filteredRows.map((row) {
                final String proofStr = (row['payment_proof'] ?? row['paymentProof'] ?? '').toString().trim();
                return DataRow(cells: [
                  ...widget.def.columns.map((k) => DataCell(Text(showValue(k, row[k]), style: const TextStyle(fontSize: 13, color: Color(0xFF171A1F))))),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    if (proofStr.isNotEmpty) IconButton(onPressed: () => _showProofDialog(proofStr), icon: const Icon(Icons.image_outlined, size: 18, color: Color(0xFFE59A2F))),
                    if (widget.def.id == 'payments') IconButton(onPressed: () => _sendWhatsApp(row), icon: const Icon(Icons.message_outlined, size: 18, color: Color(0xFF4F8A68))),
                    if (widget.def.id != 'notifications' && widget.def.id != 'whatsapp-bills') IconButton(onPressed: () => showForm(row), icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4B5563))),
                    if (widget.def.id != 'notifications' && widget.def.id != 'whatsapp-bills') IconButton(onPressed: () => del(row), icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent)),
                  ])),
                ]);
              }).toList(),
            )),
          ),
        ],
      ),
    ),
  );

  Widget _buildCards() => Column(
    children: filteredRows.asMap().entries.map((e) => AnimationConfiguration.staggeredList(
      position: e.key,
      duration: const Duration(milliseconds: 375),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: widget.def.id == 'notifications'
              ? _notificationCard(e.value)
              : _itemCard(e.value),
        ),
      ),
    )).toList(),
  );

  Widget _notificationCard(Map<String, dynamic> row) {
    final textVal = (row['text'] ?? row['message'] ?? 'Notification').toString().trim();
    final actionVal = (row['action_message'] ?? row['actionMessage'] ?? '').toString().trim();
    final timeVal = (row['time'] ?? row['created_at'] ?? '').toString().trim();
    final isRead = row['read'] == true ||
        row['read'] == 1 ||
        row['read']?.toString().toLowerCase() == 'true' ||
        row['read']?.toString() == '1' ||
        row['read']?.toString().toLowerCase() == 't';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isRead ? const Color(0xFFE7E9ED) : const Color(0xFFE59A2F).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isRead ? const Color(0xFFF6F7F9) : const Color(0xFFFFF4E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                  color: isRead ? const Color(0xFF747B84) : const Color(0xFFE59A2F),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (timeVal.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE7E9ED)),
                        ),
                        child: Text(
                          timeVal,
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF747B84)),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isRead ? const Color(0xFFF6F7F9) : const Color(0xFFFFF4E2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isRead ? const Color(0xFFE7E9ED) : const Color(0xFFE59A2F).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        isRead ? 'READ' : 'NEW',
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: isRead ? const Color(0xFF747B84) : const Color(0xFFE59A2F)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Notification Text Message
          Text(
            textVal,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
              color: const Color(0xFF171A1F),
              height: 1.4,
            ),
            softWrap: true,
          ),

          // Action Message
          if (actionVal.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7E9ED)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFFE59A2F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      actionVal,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF4B5563), height: 1.4),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> row) {
    final String dateVal = showValue('date', row['date']);
    final String statusVal = row['status']?.toString() ?? '';
    final String amountVal = row['amount'] != null ? showValue('amount', row['amount']) : '';
    final String proofStr = (row['payment_proof'] ?? row['paymentProof'] ?? '').toString().trim();

    final String primaryTitle = row['vendor']?.toString() ??
        row['customer']?.toString() ??
        row['item']?.toString() ??
        row['name']?.toString() ??
        row['category']?.toString() ??
        'Record';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E9ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE59A2F).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      dateVal,
                      style: GoogleFonts.poppins(color: const Color(0xFFE59A2F), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (statusVal.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _statusBadge(statusVal),
                  ],
                ],
              ),
              if (amountVal.isNotEmpty && amountVal != '—')
                Text(
                  amountVal,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF20252B),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF20252B), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  showValue('primary', primaryTitle),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF171A1F),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              if (proofStr.isNotEmpty)
                InkWell(
                  onTap: () => _showProofDialog(proofStr),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE59A2F).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_outlined, size: 14, color: Color(0xFFE59A2F)),
                        SizedBox(width: 6),
                        Text(
                          'Payment Proof Attached 📷',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE59A2F)),
                        ),
                      ],
                    ),
                  ),
                ),
              ...widget.def.columns
                  .where((k) => k != 'date' && k != 'status' && k != 'amount' && showValue(k, row[k] ?? (k == 'avg_cost' ? row['avgCost'] : (k == 'selling_price' ? row['sellingPrice'] : null))) != primaryTitle)
                  .map((k) {
                final dynamic rawVal = row[k] ?? (k == 'avg_cost' ? row['avgCost'] : (k == 'selling_price' ? row['sellingPrice'] : null));
                final valStr = showValue(k, rawVal);
                final isLongText = valStr.length > 35 || k == 'note' || k == 'message' || k == 'text' || k == 'action_message';

                if (isLongText) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${loc.translate(k)}:',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF747B84)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          valStr,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F), height: 1.3),
                          softWrap: true,
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${loc.translate(k)}: ',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF747B84)),
                      ),
                      Flexible(
                        child: Text(
                          valStr,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),

          if (widget.def.id != 'notifications' && widget.def.id != 'whatsapp-bills') ...[
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Divider(height: 1, color: Color(0xFFE7E9ED)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (proofStr.isNotEmpty)
                    _actionBtn(onTap: () => _showProofDialog(proofStr), icon: Icons.image_outlined, label: 'View Proof', color: const Color(0xFFE59A2F)),
                  if (widget.def.id == 'payments')
                    _actionBtn(onTap: () => _sendWhatsApp(row), icon: Icons.message_outlined, label: loc.translate('WhatsApp'), color: const Color(0xFF4F8A68)),
                  _actionBtn(onTap: () => showForm(row), icon: Icons.edit_outlined, label: loc.translate('edit'), color: const Color(0xFF4B5563)),
                  _actionBtn(onTap: () => del(row), icon: Icons.delete_outline, label: loc.translate('delete'), color: Colors.redAccent),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showProofDialog(String proofStr) {
    Widget imageWidget;
    if (proofStr.startsWith('data:image')) {
      try {
        final base64Str = proofStr.split(',').last;
        final bytes = base64Decode(base64Str);
        imageWidget = Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        imageWidget = const Center(child: Text('Invalid image data.', style: TextStyle(color: Color(0xFF747B84))));
      }
    } else {
      imageWidget = Image.network(
        proofStr,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(child: Text('Could not load image.', style: TextStyle(color: Color(0xFF747B84)))),
      );
    }

    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Payment Proof', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 360,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              child: imageWidget,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close', style: TextStyle(color: Color(0xFF20252B), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({required VoidCallback onTap, required IconData icon, required String label, required Color color}) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(8),
    child: Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))])),
  );

  Widget _statusBadge(String status) {
    Color c = status == 'Paid' || status == 'Available' ? const Color(0xFF4F8A68) : (status == 'Due' || status == 'Overdue' ? Colors.redAccent : const Color(0xFF4B5563));
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(loc.translate(status).toUpperCase(), style: GoogleFonts.poppins(color: c, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)));
  }

  Future<void> _sendWhatsApp(Map<String, dynamic> row) async {
    final rawPhone = row['phone']?.toString() ?? '', customer = row['customer']?.toString() ?? 'Customer', amount = row['amount']?.toString() ?? '0', type = row['type']?.toString() ?? 'Due', date = row['date']?.toString() ?? '';
    if (rawPhone.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number found.'))); return; }
    final phone = _normalizePhone(rawPhone);
    final msg = Uri.encodeComponent('Sabzi Setu: ${type == 'Payment' ? 'Payment Receipt' : 'Payment Reminder'} for $customer.\nAmount: ₹$amount\nDate: $date\nStatus: ${type == 'Payment' ? 'Paid' : 'Due'}\nThank you!');
    final url = 'https://wa.me/$phone?text=$msg';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      await widget.api.logWhatsAppReminderOpened(customer, rawPhone, num.tryParse(amount) ?? 0);
    }
  }
  String _normalizePhone(String p) { final d = p.replaceAll(RegExp(r'\D'), ''); return d.length == 10 ? '91$d' : d; }
}

class _ResourceFormDialog extends StatefulWidget {
  const _ResourceFormDialog({required this.def, this.existing, this.masters, required this.translate, required this.masterOptions, required this.usesMasterSuggestions});
  final ResourceDef def; final Map<String, dynamic>? existing, masters; final String Function(String) translate; final List<String> Function(String) masterOptions; final bool Function(String) usesMasterSuggestions;
  @override State<_ResourceFormDialog> createState() => _ResourceFormDialogState();
}

class _ResourceFormDialogState extends State<_ResourceFormDialog> {
  late final Map<String, TextEditingController> _controllers;
  String _paymentMethod = 'Cash';
  XFile? _proofImage;
  String? _existingProofStr;

  // Multi-item transaction lines state
  final List<Map<String, dynamic>> _itemLines = [];

  @override
  void initState() {
    super.initState();
    final isEdit = widget.existing != null;
    _controllers = {
      for (final f in widget.def.fields)
        f.key: TextEditingController(
          text: isEdit
              ? (widget.existing![f.key]?.toString() ??
                 widget.existing![f.key == 'avg_cost' ? 'avgCost' : (f.key == 'selling_price' ? 'sellingPrice' : f.key)]?.toString() ??
                 '')
              : (f.key == 'date' ? DateTime.now().toIso8601String().substring(0, 10) : f.defaultValue),
        )
    };
    if (isEdit) {
      final rawMethod = (widget.existing!['payment_method'] ?? 'Cash').toString().trim().toUpperCase();
      if (rawMethod == 'UPI') {
        _paymentMethod = 'UPI';
      } else if (rawMethod == 'BANK') {
        _paymentMethod = 'Bank';
      } else {
        _paymentMethod = 'Cash';
      }

      if (widget.existing!['payment_proof'] != null && widget.existing!['payment_proof'].toString().trim().isNotEmpty) {
        _existingProofStr = widget.existing!['payment_proof'].toString().trim();
      }
    }

    if (_isMultiItemForm && !isEdit) {
      _addItemLine();
    }
  }

  bool get _isMultiItemForm =>
      widget.def.id == 'mandi-purchases' ||
      widget.def.id == 'local-purchases' ||
      widget.def.id == 'sales';

  void _addItemLine() {
    setState(() {
      _itemLines.add({
        'itemCtrl': TextEditingController(),
        'specCtrl': TextEditingController(),
        'qtyCtrl': TextEditingController(),
        'rateCtrl': TextEditingController(),
        'unit': 'Kg',
      });
    });
  }

  void _removeItemLine(int index) {
    if (_itemLines.length > 1) {
      setState(() {
        final removed = _itemLines.removeAt(index);
        (removed['itemCtrl'] as TextEditingController).dispose();
        (removed['specCtrl'] as TextEditingController).dispose();
        (removed['qtyCtrl'] as TextEditingController).dispose();
        (removed['rateCtrl'] as TextEditingController).dispose();
      });
    }
  }

  double _calculateLineAmount(Map<String, dynamic> line) {
    final qty = double.tryParse((line['qtyCtrl'] as TextEditingController).text.trim()) ?? 0.0;
    final rate = double.tryParse((line['rateCtrl'] as TextEditingController).text.trim()) ?? 0.0;
    final unitSymbol = line['unit']?.toString() ?? 'Kg';

    double multiplier = 1.0;
    final unitsList = widget.masters?['units'] as List? ?? [];
    for (final u in unitsList) {
      if (u is Map && (u['symbol'] == unitSymbol || u['name'] == unitSymbol)) {
        multiplier = double.tryParse(u['kg_multiplier']?.toString() ?? u['kgMultiplier']?.toString() ?? '1') ?? 1.0;
        break;
      }
    }

    return (qty * multiplier) * rate;
  }

  double _calculateTransactionTotal() {
    double total = 0.0;
    for (final line in _itemLines) {
      total += _calculateLineAmount(line);
    }
    return total;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final line in _itemLines) {
      (line['itemCtrl'] as TextEditingController).dispose();
      (line['specCtrl'] as TextEditingController).dispose();
      (line['qtyCtrl'] as TextEditingController).dispose();
      (line['rateCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
      if (picked != null) {
        setState(() { _proofImage = picked; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final isPaymentOrSale = widget.def.id == 'payments' || widget.def.id == 'sales';

    final dialogTitle = widget.def.id == 'mandi-purchases'
        ? (isEdit ? 'Edit Mandi Purchase' : 'Add Mandi Purchase')
        : widget.def.id == 'local-purchases'
            ? (isEdit ? 'Edit Local Purchase' : 'Add Local Purchase')
            : widget.def.id == 'sales'
                ? (isEdit ? 'Edit Sale / Supply' : 'Add Sale / Supply')
                : isEdit
                    ? '${widget.translate(widget.def.title)} ${widget.translate('edit')}'
                    : '${widget.translate(widget.def.title)} ${widget.translate('add')}';

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(dialogTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isMultiItemForm && !isEdit) ...[
                  // Multi-Item Form Header (Date + Vendor/Customer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: _controllers['date'] ?? TextEditingController(),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        hintText: 'YYYY-MM-DD',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SafeSuggestionField(
                      controller: _controllers[widget.def.id == 'sales' ? 'customer' : 'vendor'] ?? TextEditingController(),
                      options: widget.masterOptions(widget.def.id == 'sales' ? 'customer' : 'vendor'),
                      label: widget.def.id == 'sales'
                          ? 'Customer Name *'
                          : widget.def.id == 'local-purchases'
                              ? 'Vendor / Farmer Name *'
                              : 'Mandi / Vendor Name *',
                    ),
                  ),
                  if (widget.def.id == 'sales')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextField(
                        controller: _controllers['phone'] ?? TextEditingController(),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Customer Mobile Number'),
                      ),
                    ),

                  const Divider(height: 24, color: Color(0xFFE7E9ED)),

                  // Multi-Item Section Header + Add Item Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.def.id == 'sales' ? 'Sale Items' : 'Purchase Items',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF171A1F)),
                            ),
                            Text(
                              widget.def.id == 'sales'
                                  ? 'Add multiple vegetables in the same sale supply.'
                                  : 'Add multiple vegetables in the same purchase.',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF747B84)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _addItemLine,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF4E2),
                          foregroundColor: const Color(0xFFE59A2F),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Item Cards List
                  ..._itemLines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;
                    final lineAmount = _calculateLineAmount(line);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE7E9ED)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ITEM ${index + 1}',
                                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF747B84), letterSpacing: 0.5),
                              ),
                              if (_itemLines.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                  onPressed: () => _removeItemLine(index),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _SafeSuggestionField(
                            controller: line['itemCtrl'] as TextEditingController,
                            options: widget.masterOptions('item'),
                            label: 'Type vegetable name...',
                            fontSize: 12,
                          ),
                          const SizedBox(height: 12),
                          _SafeSuggestionField(
                            controller: line['specCtrl'] as TextEditingController,
                            options: const [],
                            label: 'Specification (Optional)',
                            fontSize: 12,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: line['qtyCtrl'] as TextEditingController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
                                  decoration: const InputDecoration(
                                    labelText: 'Quantity *',
                                    labelStyle: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: Builder(
                                  builder: (context) {
                                    final rawMaster = widget.masterOptions('quantity_unit');
                                    final normalizedMaster = rawMaster
                                        .map((u) => u.trim())
                                        .where((u) => u.isNotEmpty)
                                        .toSet()
                                        .toList();
                                    const fallbackUnits = ['Kg', 'Quintal', 'Bag', 'Carat'];
                                    final availableUnits = normalizedMaster.isEmpty ? fallbackUnits : normalizedMaster;

                                    final currentUnitStr = (line['unit'] ?? 'Kg').toString().trim();

                                    final matchedUnit = availableUnits.firstWhere(
                                      (u) => u == currentUnitStr,
                                      orElse: () => availableUnits.firstWhere(
                                        (u) => u.toLowerCase() == currentUnitStr.toLowerCase(),
                                        orElse: () => availableUnits.first,
                                      ),
                                    );

                                    final dropdownItems = availableUnits.contains(matchedUnit)
                                        ? availableUnits
                                        : [...availableUnits, matchedUnit];

                                    return DropdownButtonFormField<String>(
                                      key: ValueKey('mandi_unit_selector_$index'),
                                      value: matchedUnit,
                                      decoration: const InputDecoration(
                                        labelText: 'Unit',
                                        labelStyle: TextStyle(fontSize: 11),
                                      ),
                                      isExpanded: true,
                                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
                                      selectedItemBuilder: (BuildContext context) {
                                        return dropdownItems.map((u) {
                                          return Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              u,
                                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList();
                                      },
                                      items: dropdownItems
                                          .map((u) => DropdownMenuItem<String>(
                                                value: u,
                                                child: Text(
                                                  u,
                                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() {
                                            line['unit'] = v;
                                          });
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: line['rateCtrl'] as TextEditingController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
                                  decoration: InputDecoration(
                                    labelText: 'Rate (₹/${(line['unit'] ?? 'Kg').toString().trim()}) *',
                                    labelStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Amount', style: TextStyle(fontSize: 8, color: Color(0xFF747B84))),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '₹${lineAmount == lineAmount.roundToDouble() ? lineAmount.toStringAsFixed(0) : lineAmount.toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  // Total Box with Clear Vertical Margin
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE59A2F).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.def.id == 'sales' ? 'Sale Total' : 'Purchase Total',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFFE59A2F)),
                        ),
                        Text(
                          '₹${_calculateTransactionTotal() == _calculateTransactionTotal().roundToDouble() ? _calculateTransactionTotal().toStringAsFixed(0) : _calculateTransactionTotal().toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFFE59A2F)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Standard Single-Item Form fields
                  ...widget.def.fields
                      .where((f) => f.key != 'payment_method' && f.key != 'transaction_id')
                      .map((f) {
                    final c = _controllers[f.key]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: widget.usesMasterSuggestions(f.key)
                          ? _SafeSuggestionField(controller: c, options: widget.masterOptions(f.key), label: widget.translate(f.label) + (f.required ? ' *' : ''))
                          : TextField(
                              controller: c,
                              keyboardType: f.numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
                              decoration: InputDecoration(labelText: widget.translate(f.label) + (f.required ? ' *' : '')),
                            ),
                    );
                  }),
                ],

                if (isPaymentOrSale) ...[
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() { _paymentMethod = v; });
                    },
                  ),
                  const SizedBox(height: 16),

                  if (_paymentMethod == 'UPI') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                    if (_proofImage != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(_proofImage!.path), width: 60, height: 60, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('New payment proof attached.', style: TextStyle(color: Color(0xFF4F8A68), fontWeight: FontWeight.bold, fontSize: 12))),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.redAccent),
                            onPressed: () => setState(() { _proofImage = null; }),
                          ),
                        ],
                      ),
                    ] else if (_existingProofStr != null && _existingProofStr!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _existingProofStr!.startsWith('data:image')
                                ? Image.memory(base64Decode(_existingProofStr!.split(',').last), width: 60, height: 60, fit: BoxFit.cover)
                                : Image.network(_existingProofStr!, width: 60, height: 60, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Saved payment proof attached.', style: TextStyle(color: Color(0xFF4F8A68), fontWeight: FontWeight.bold, fontSize: 12))),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.redAccent),
                            onPressed: () => setState(() { _existingProofStr = null; }),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  if (_paymentMethod == 'Bank') ...[
                    TextField(
                      controller: _controllers['transaction_id'] ?? TextEditingController(),
                      decoration: const InputDecoration(labelText: 'Bank Transaction ID *'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () { FocusManager.instance.primaryFocus?.unfocus(); Navigator.pop(context); }, child: Text(widget.translate('cancel'), style: const TextStyle(color: Color(0xFF747B84)))),
          ElevatedButton.icon(
            onPressed: () async {
              String? proofBase64 = _existingProofStr;
              if (_proofImage != null) {
                try {
                  final bytes = await _proofImage!.readAsBytes();
                  proofBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                } catch (_) {}
              }

              if (_isMultiItemForm && !isEdit) {
                final primaryKey = widget.def.id == 'sales' ? 'customer' : 'vendor';
                final primaryName = _controllers[primaryKey]?.text.trim() ?? '';
                final phone = _controllers['phone']?.text.trim() ?? '';
                final date = _controllers['date']?.text.trim() ?? DateTime.now().toIso8601String().substring(0, 10);

                if (primaryName.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${widget.def.id == 'sales' ? 'Customer' : 'Vendor'} name is required.'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  return;
                }

                final List<Map<String, dynamic>> multiPayloads = [];

                for (int i = 0; i < _itemLines.length; i++) {
                  final line = _itemLines[i];
                  final item = (line['itemCtrl'] as TextEditingController).text.trim();
                  final spec = (line['specCtrl'] as TextEditingController).text.trim();

                  final rawQty = (line['qtyCtrl'] as TextEditingController).text.trim().replaceAll(',', '');
                  final rawRate = (line['rateCtrl'] as TextEditingController).text.replaceAll('₹', '').replaceAll(',', '').trim();

                  final qtyVal = num.tryParse(rawQty);
                  final rateVal = num.tryParse(rawRate);
                  final unitVal = line['unit']?.toString() ?? 'Kg';

                  if (item.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Item ${i + 1}: Please enter a vegetable name.'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return;
                  }

                  if (qtyVal == null || qtyVal <= 0) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Item ${i + 1} ($item): Quantity must be greater than 0.'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return;
                  }

                  if (rateVal == null || rateVal < 0) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Item ${i + 1} ($item): Rate cannot be negative.'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return;
                  }

                  final payload = <String, dynamic>{
                    'date': date,
                    primaryKey: primaryName,
                    'item': item,
                    'specification': spec,
                    'qty': qtyVal,
                    'quantity_value': qtyVal,
                    'quantityValue': qtyVal,
                    'quantity_unit': unitVal,
                    'quantityUnit': unitVal,
                    'rate': rateVal,
                  };
                  if (widget.def.id == 'sales') {
                    payload['phone'] = phone;
                    payload['payment_method'] = _paymentMethod;
                    if (_paymentMethod == 'UPI' && proofBase64 != null) {
                      payload['payment_proof'] = proofBase64;
                    }
                  }
                  multiPayloads.add(payload);
                }

                if (!mounted) return;
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(context, multiPayloads);
                return;
              }

              // Standard single item save
              final body = <String, dynamic>{};
              for (final f in widget.def.fields) {
                final t = _controllers[f.key]!.text.trim();
                if (f.required && t.isEmpty) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.translate(f.label)} ${widget.translate('is required')}')));
                  return;
                }
                if (t.isNotEmpty) {
                  if (f.numeric) {
                    final n = num.tryParse(t.replaceAll('₹', '').replaceAll(',', '').trim());
                    if (n == null) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.translate(f.label)} must be a number')));
                      return;
                    }
                    body[f.key] = n;
                  } else { body[f.key] = t; }
                }
              }
              if (isPaymentOrSale) {
                body['payment_method'] = _paymentMethod;
                if (_paymentMethod == 'UPI' && proofBase64 != null) {
                  body['payment_proof'] = proofBase64;
                }
                if (_paymentMethod == 'Bank') {
                  final tx = _controllers['transaction_id']?.text.trim() ?? '';
                  if (tx.isEmpty) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bank Transaction ID is required.')));
                    return;
                  }
                  body['transaction_id'] = tx;
                }
              }
              if (!mounted) return;
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context, body);
            },
            icon: const Icon(Icons.check, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: AppTheme.onAccentColor,
            ),
            label: Text(_isMultiItemForm && !isEdit ? 'Save Transaction' : widget.translate('save')),
          ),
        ],
      ),
    );
  }
}

class _SafeSuggestionField extends StatefulWidget {
  const _SafeSuggestionField({
    required this.controller,
    required this.options,
    required this.label,
    this.fontSize = 14,
  });
  final TextEditingController controller;
  final List<String> options;
  final String label;
  final double fontSize;
  @override State<_SafeSuggestionField> createState() => _SafeSuggestionFieldState();
}

class _SafeSuggestionFieldState extends State<_SafeSuggestionField> {
  late final FocusNode _focusNode; List<String> _suggestions = [];
  @override void initState() { super.initState(); _focusNode = FocusNode(); _focusNode.addListener(_handleFocusChanged); }
  void _handleFocusChanged() { if (!mounted) return; if (_focusNode.hasFocus) { _updateSuggestions(widget.controller.text); } else { setState(() { _suggestions = []; }); } }
  void _updateSuggestions(String text) {
    final q = text.trim().toLowerCase();
    if (q.isEmpty) { setState(() { _suggestions = widget.options.take(6).toList(); }); return; }
    final m = widget.options.where((o) => o.toLowerCase().contains(q)).toList();
    m.sort((a, b) {
      final aS = a.toLowerCase().startsWith(q), bS = b.toLowerCase().startsWith(q);
      if (aS && !bS) return -1;
      if (!aS && bS) return 1;
      return a.compareTo(b);
    });
    if (mounted) setState(() { _suggestions = m.take(6).toList(); });
  }
  void _selectSuggestion(String v) { widget.controller.text = v; widget.controller.selection = TextSelection.collapsed(offset: v.length); if (mounted) setState(() { _suggestions = []; }); _focusNode.unfocus(); }
  @override void dispose() { _focusNode.removeListener(_handleFocusChanged); Future.microtask(() { if (_focusNode.hasFocus) { _focusNode.unfocus(); } _focusNode.dispose(); }); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: _updateSuggestions,
        style: GoogleFonts.poppins(fontSize: widget.fontSize, fontWeight: FontWeight.w500, color: const Color(0xFF171A1F)),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(fontSize: widget.fontSize),
          suffixIcon: widget.options.isEmpty ? null : const Icon(Icons.search_rounded, size: 20, color: Color(0xFFE59A2F)),
        ),
      ),
      if (_focusNode.hasFocus && _suggestions.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E9ED)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: _suggestions.map((s) => InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _selectSuggestion(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFFE59A2F)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF171A1F)),
                      ),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ),
        ),
    ]);
  }
}
