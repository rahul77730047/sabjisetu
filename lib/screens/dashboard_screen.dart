import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api_client.dart';
import '../core/localization.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.api,
    this.onViewNotifications,
  });

  final ApiClient api;
  final VoidCallback? onViewNotifications;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final loc = Localization();
  Map<String, dynamic>? summary;
  List<Map<String, dynamic>> trend = [];
  List<Map<String, dynamic>> customersList = [];
  List<Map<String, dynamic>> salesList = [];
  List<Map<String, dynamic>> mandiPurchasesList = [];
  List<Map<String, dynamic>> localPurchasesList = [];
  List<Map<String, dynamic>> stockList = [];
  String? error;
  bool loading = true;

  // Independent Visibility-Triggered Animation Controllers for Circular Charts
  late AnimationController _dueAnimationController;
  late AnimationController _paymentsAnimationController;

  final GlobalKey _dueKey = GlobalKey();
  final GlobalKey _paymentsKey = GlobalKey();

  bool _dueAnimated = false;
  bool _paymentsAnimated = false;

  @override
  void initState() {
    super.initState();

    _dueAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _paymentsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    load();
  }

  @override
  void dispose() {
    _dueAnimationController.dispose();
    _paymentsAnimationController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([
        widget.api.summary(),
        widget.api.trend(),
        widget.api.list('customers'),
        widget.api.list('sales'),
        widget.api.list('mandi-purchases'),
        widget.api.list('local-purchases'),
        widget.api.list('stock'),
      ]);
      if (!mounted) return;

      final sumMap = results[0] as Map<String, dynamic>;
      final requiredSummaryKeys = [
        'total_due',
        'collected_today',
        'sales_today',
        'purchases_today'
      ];
      for (final k in requiredSummaryKeys) {
        if (!sumMap.containsKey(k) || sumMap[k] == null) {
          throw Exception('Dashboard API contract incomplete: missing $k');
        }
      }

      setState(() {
        summary = sumMap;
        trend = List<Map<String, dynamic>>.from(results[1] as Iterable);
        customersList = List<Map<String, dynamic>>.from(results[2] as Iterable);
        salesList = List<Map<String, dynamic>>.from(results[3] as Iterable);
        mandiPurchasesList = List<Map<String, dynamic>>.from(results[4] as Iterable);
        localPurchasesList = List<Map<String, dynamic>>.from(results[5] as Iterable);
        stockList = List<Map<String, dynamic>>.from(results[6] as Iterable);
        error = null;
        loading = false;
        _dueAnimated = false;
        _paymentsAnimated = false;
      });

      _dueAnimationController.reset();
      _paymentsAnimationController.reset();

      // Check initial visibility after frame render
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString().replaceAll('Exception: ', ''); loading = false; });
    }
  }

  void _checkVisibility() {
    if (!mounted) return;
    final screenHeight = MediaQuery.of(context).size.height;

    if (!_dueAnimated && _dueKey.currentContext != null) {
      final box = _dueKey.currentContext!.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final pos = box.localToGlobal(Offset.zero);
        if (pos.dy < screenHeight - 20 && pos.dy + box.size.height > 20) {
          _dueAnimated = true;
          _dueAnimationController.forward(from: 0.0);
        }
      }
    }

    if (!_paymentsAnimated && _paymentsKey.currentContext != null) {
      final box = _paymentsKey.currentContext!.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final pos = box.localToGlobal(Offset.zero);
        if (pos.dy < screenHeight - 20 && pos.dy + box.size.height > 20) {
          _paymentsAnimated = true;
          _paymentsAnimationController.forward(from: 0.0);
        }
      }
    }
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

  String _qty(dynamic value) {
    final number = _number(value);
    if (number == number.roundToDouble()) return number.toStringAsFixed(0);
    return number.toStringAsFixed(2);
  }

  List<dynamic> _list(String key) => summary?[key] is List ? summary![key] : const [];
  Map<String, dynamic>? _map(String key) => summary?[key] is Map ? Map<String, dynamic>.from(summary![key]) : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: RefreshIndicator(
        onRefresh: load,
        color: const Color(0xFFE59A2F),
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
            _checkVisibility();
            return false;
          },
          child: AnimationLimiter(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 500),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 30.0,
                  child: FadeInAnimation(child: widget),
                ),
                children: [
                  _header(context),
                  const SizedBox(height: 20),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFFE59A2F))),
                    )
                  else if (error != null)
                    _errorState()
                  else if (summary == null)
                    Center(child: Text(loc.translate('No dashboard data available.')))
                  else ...[
                    _businessPulse(),
                    const SizedBox(height: 20),
                    _statGrid(),
                    const SizedBox(height: 20),
                    _buildResponsiveRow([
                      _summaryCard(loc.translate('Purchase Summary (Today)'), _purchaseSummaryContent()),
                      Container(key: _dueKey, child: _summaryCard(loc.translate('Due Summary'), _dueSummaryContent())),
                    ]),
                    const SizedBox(height: 8),
                    _buildResponsiveRow([
                      _summaryCard(loc.translate('Top Selling Sabji (Today)'), _topSelling()),
                      Container(key: _paymentsKey, child: _summaryCard(loc.translate('Payment Overview'), _paymentOverviewContent())),
                    ]),
                    const SizedBox(height: 8),
                    _summaryCard(loc.translate('Current Stock Snapshot'), _stockTable()),
                    const SizedBox(height: 8),
                    _buildResponsiveRow([
                      _recentDueList(),
                      _summaryCard(loc.translate('Recent Sales'), _recentSales()),
                    ]),
                    const SizedBox(height: 8),
                    _summaryCard(loc.translate('Stock Alerts'), _stockAlerts()),
                    const SizedBox(height: 20),
                    _monthlySummary(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Premium Light Analytics Card for Business Pulse
  Widget _businessPulse() {
    return Container(
      height: 230,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7E9ED), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE59A2F),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${loc.translate('Business Pulse')} (7 Days)',
                    style: GoogleFonts.poppins(color: const Color(0xFF20252B), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE59A2F).withValues(alpha: 0.3)),
                ),
                child: Text('LIVE ANALYTICS', style: GoogleFonts.poppins(color: const Color(0xFFE59A2F), fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(loc.translate('Sales vs Purchase'), style: GoogleFonts.poppins(color: const Color(0xFF747B84), fontSize: 13, fontWeight: FontWeight.w500)),
          const Expanded(child: SizedBox(height: 10)),
          Expanded(
            flex: 8,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _lineBarData(trend.map((e) => _number(e['sales'])).toList(), const Color(0xFFE59A2F)),
                  _lineBarData(trend.map((e) => _number(e['purchase'])).toList(), const Color(0xFF4B5563)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _lineBarData(List<double> data, Color color) {
    if (data.isEmpty) data = [0, 0, 0, 0, 0, 0, 0];
    return LineChartBarData(
      spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
    );
  }

  // Redesigned Metric Analytics Cards
  Widget _statGrid() {
    final double sales = _number(summary?['sales_today']);
    final double cogs = _number(summary?['cogs_today']);
    final double grossProfit = sales - cogs;
    final double margin = sales > 0 ? (grossProfit / sales) * 100 : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = constraints.maxWidth >= 700 ? (constraints.maxWidth - 32) / 3 : (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _glassStatCard(cardWidth, loc.translate("today's purchase"), _money(summary?['purchases_today']), Icons.shopping_bag_outlined, const Color(0xFFE59A2F), '${loc.translate('qty')}: ${_qty(summary?['purchases_qty_today'])} Kg'),
            _glassStatCard(cardWidth, loc.translate("today's sales"), _money(sales), Icons.trending_up_rounded, const Color(0xFF4F8A68), '${loc.translate('qty')}: ${_qty(summary?['sales_qty_today'])} Kg'),
            _glassStatCard(cardWidth, loc.translate('gross profit'), _money(grossProfit), Icons.payments_outlined, const Color(0xFF20252B), 'Margin: ${margin.toStringAsFixed(1)}%'),
            _glassStatCard(cardWidth, loc.translate('net profit'), _money(grossProfit - _number(summary?['expenses_today']) - _number(summary?['labour_today'])), Icons.query_stats_rounded, const Color(0xFF4B5563), 'After Expenses'),
          ],
        );
      },
    );
  }

  Widget _glassStatCard(double width, String title, String value, IconData icon, Color color, String sub) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7E9ED), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF6F7F9), borderRadius: BorderRadius.circular(8)),
                child: Text(sub, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF747B84), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F), letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _purchaseSummaryContent() {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final todayMandiTotal = mandiPurchasesList
        .where((p) => (p['date'] ?? '').toString().startsWith(todayStr))
        .fold(0.0, (s, p) => s + _number(p['amount']));
    final todayLocalTotal = localPurchasesList
        .where((p) => (p['date'] ?? '').toString().startsWith(todayStr))
        .fold(0.0, (s, p) => s + _number(p['amount']));

    final mandiVal = summary?.containsKey('purchases_mandi_today') == true && summary!['purchases_mandi_today'] != null
        ? _number(summary!['purchases_mandi_today'])
        : todayMandiTotal;
    final localVal = summary?.containsKey('purchases_local_today') == true && summary!['purchases_local_today'] != null
        ? _number(summary!['purchases_local_today'])
        : todayLocalTotal;
    final totalVal = _number(summary?['purchases_today'] ?? (mandiVal + localVal));

    return Column(children: [
      _summaryRow(loc.translate('mandi purchase'), _money(mandiVal), const Color(0xFFE59A2F)),
      _summaryRow(loc.translate('local purchase'), _money(localVal), const Color(0xFF4B5563)),
      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFE7E9ED))),
      _summaryRow(loc.translate("today's purchase"), _money(totalVal), const Color(0xFF20252B)),
    ]);
  }

  Widget _dueSummaryContent() {
    final double totalDue = _number(summary?['total_due'] ?? customersList.fold(0.0, (s, c) => s + _number(c['due'])));

    final double overdue = customersList
        .where((c) => c['status'] == 'Overdue')
        .fold(0.0, (s, c) => s + _number(c['due']));
    final double today = customersList
        .where((c) => c['status'] == 'Due Today')
        .fold(0.0, (s, c) => s + _number(c['due']));
    final double upcoming = customersList
        .where((c) => c['status'] == 'Upcoming' && _number(c['due']) > 0)
        .fold(0.0, (s, c) => s + _number(c['due']));

    return Column(children: [
      SizedBox(height: 140, child: _donutChartDues(overdue, today, upcoming, totalDue)),
      const SizedBox(height: 20),
      _summaryRow(loc.translate('overdue'), _money(overdue), Colors.redAccent),
      _summaryRow(loc.translate('due today'), _money(today), const Color(0xFFE59A2F)),
      _summaryRow(loc.translate('upcoming'), _money(upcoming), const Color(0xFF4B5563)),
    ]);
  }

  Widget _paymentOverviewContent() {
    final double collected = _number(summary?['collected_today']);
    final double totalDue = _number(summary?['total_due'] ?? customersList.fold(0.0, (s, c) => s + _number(c['due'])));
    final double salesStillDue = summary?.containsKey('sales_still_due') == true && summary!['sales_still_due'] != null
        ? _number(summary!['sales_still_due'])
        : totalDue;

    return Column(children: [
      SizedBox(height: 140, child: _donutChartPayments(collected, salesStillDue)),
      const SizedBox(height: 20),
      _summaryRow(loc.translate('Collected Today'), _money(collected), const Color(0xFF4F8A68)),
      _summaryRow(loc.translate('Sales Still Due'), _money(salesStillDue), Colors.redAccent),
    ]);
  }

  Widget _monthlySummary() => _summaryCard(loc.translate('this month performance'), Column(children: [
    _summaryRow(loc.translate('monthly sales'), _money(summary!['sales_month']), const Color(0xFF4F8A68)),
    _summaryRow(loc.translate('monthly purchase'), _money(summary!['purchases_month']), const Color(0xFFE59A2F)),
    _summaryRow(loc.translate('Total Expenses'), _money(_number(summary!['expenses_month']) + _number(summary!['labour_month'])), Colors.redAccent),
    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFE7E9ED))),
    _summaryRow(loc.translate('Net Profit'), _money(_number(summary!['sales_month']) - _number(summary!['cogs_month']) - _number(summary!['expenses_month']) - _number(summary!['labour_month'])), const Color(0xFF20252B)),
  ]));

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4F8A68), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(loc.translate('Live Business Pulse'), style: GoogleFonts.poppins(color: const Color(0xFF747B84), fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E9ED))),
          child: IconButton(
            onPressed: widget.onViewNotifications,
            icon: FutureBuilder<List<Map<String, dynamic>>>(
              future: widget.api.list('notifications'),
              builder: (context, snapshot) {
                final count = (snapshot.data ?? []).where((n) => n['read'] == false).length;
                if (count > 0) {
                  return Badge(
                    label: Text(count.toString()),
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF20252B)),
                  );
                }
                return const Icon(Icons.notifications_none_rounded, color: Color(0xFF20252B));
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 50, color: Color(0xFF747B84)),
          const SizedBox(height: 12),
          Text(error ?? loc.translate('Unable to load dashboard.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: load, child: Text(loc.translate('Retry'))),
        ],
      ),
    );
  }

  Widget _topSelling() {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final todaySales = salesList.where((s) {
      final d = (s['date'] ?? s['created_at'] ?? '').toString();
      return d.startsWith(todayStr);
    }).toList();

    String itemLabelStr = '';
    double qty = 0.0;

    if (todaySales.isNotEmpty) {
      final map = <String, double>{};
      for (final s in todaySales) {
        final it = (s['item'] ?? '').toString().trim();
        final spec = (s['specification'] ?? '').toString().trim();
        if (it.isNotEmpty) {
          final key = spec.isNotEmpty ? '$it ($spec)' : it;
          final q = _number(s['qty'] ?? s['quantity_value']);
          map[key] = (map[key] ?? 0.0) + q;
        }
      }
      for (final entry in map.entries) {
        if (entry.value > qty) {
          itemLabelStr = entry.key;
          qty = entry.value;
        }
      }
    }

    if (itemLabelStr.isEmpty) {
      final topMap = _map('top_selling_today');
      if (topMap != null && topMap.isNotEmpty) {
        itemLabelStr = topMap['item']?.toString().trim() ?? '';
        final spec = topMap['specification']?.toString().trim() ?? '';
        if (spec.isNotEmpty && !itemLabelStr.contains('(')) {
          itemLabelStr = '$itemLabelStr ($spec)';
        }
        qty = _number(topMap['qty']);
      }
    }

    if (itemLabelStr.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            loc.translate('No sales recorded today.'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF747B84)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              itemLabelStr.toUpperCase(),
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF171A1F)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE59A2F).withValues(alpha: 0.3)),
            ),
            child: Text(
              '${_qty(qty)} Kg',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFFE59A2F)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockTable() {
    List<dynamic> list = _list('stock_snapshot');
    if (list.isEmpty) {
      list = stockList.take(8).toList();
    }

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(loc.translate('No stock data.'), style: const TextStyle(color: Color(0xFF747B84))),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        horizontalMargin: 0,
        columnSpacing: 20,
        columns: [
          DataColumn(label: Text(loc.translate('ITEM'), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF20252B)))),
          DataColumn(label: Text(loc.translate('QTY'), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF20252B)))),
          DataColumn(label: Text(loc.translate('AVG COST'), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF20252B)))),
          DataColumn(label: Text(loc.translate('Rate'), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF20252B)))),
          DataColumn(label: Text(loc.translate('STATUS'), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF20252B)))),
        ],
        rows: list.take(10).map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          final String status = item['status']?.toString() ?? 'Available';
          final String itemName = item['item']?.toString() ?? '—';
          final String spec = item['specification']?.toString().trim() ?? '';
          final String displayItem = spec.isNotEmpty ? '$itemName\n$spec' : itemName;

          return DataRow(cells: [
            DataCell(Text(displayItem, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF171A1F)))),
            DataCell(Text('${_qty(item['qty'])} Kg', style: const TextStyle(fontSize: 13))),
            DataCell(Text(_money(item['avg_cost'] ?? item['avgCost']), style: const TextStyle(fontSize: 13))),
            DataCell(Text(_money(item['selling_price'] ?? item['sellingPrice']), style: const TextStyle(fontSize: 13))),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: (status == 'Available' ? const Color(0xFF4F8A68) : Colors.redAccent).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(loc.translate(status), style: TextStyle(color: status == 'Available' ? const Color(0xFF4F8A68) : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10)),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _recentSales() {
    List<dynamic> list = _list('recent_sales');
    if (list.isEmpty) {
      list = salesList.take(5).toList();
    }

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(loc.translate('No recent sales.'), style: const TextStyle(color: Color(0xFF747B84))),
        ),
      );
    }

    return Column(
      children: list.map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        final String itemName = item['item']?.toString() ?? '—';
        final String custName = item['customer']?.toString() ?? 'Customer';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            CircleAvatar(radius: 4, backgroundColor: const Color(0xFFE59A2F)),
            const SizedBox(width: 10),
            Expanded(child: Text('$itemName • $custName', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF171A1F)))),
            Text(_money(item['amount']), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF20252B))),
          ]),
        );
      }).toList(),
    );
  }

  Widget _stockAlerts() {
    List<dynamic> list = _list('stock_alerts');
    if (list.isEmpty) {
      list = stockList.where((s) {
        final double q = _number(s['qty']);
        final String st = (s['status'] ?? '').toString();
        return q <= 0 || RegExp(r'low|urgent|out', caseSensitive: false).hasMatch(st);
      }).take(5).toList();
    }

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(loc.translate('All stock levels healthy.'), style: const TextStyle(color: Color(0xFF747B84), fontSize: 12)),
        ),
      );
    }

    return Column(
      children: list.map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFFF4E2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE59A2F).withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFE59A2F), size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(item['item']?.toString() ?? 'Unknown', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF171A1F)))),
            Text('${loc.translate('Only')} ${_qty(item['qty'])} Kg ${loc.translate('left')}', style: const TextStyle(fontSize: 12, color: Color(0xFF747B84))),
          ]),
        );
      }).toList(),
    );
  }

  Widget _recentDueList() {
    List<dynamic> list = _list('recent_dues');
    if (list.isEmpty) {
      list = customersList
          .where((c) => _number(c['due']) > 0)
          .take(5)
          .toList();
    }

    return _summaryCard(
      loc.translate('Recent Due List'),
      list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  loc.translate('No outstanding dues'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF747B84)),
                ),
              ),
            )
          : Column(
              children: list.map((raw) {
                final due = Map<String, dynamic>.from(raw as Map);
                return _dueItem(
                  due['name']?.toString() ?? 'Unknown',
                  due['phone']?.toString() ?? 'No phone',
                  _money(due['due']),
                  due['status']?.toString() ?? 'Upcoming',
                );
              }).toList(),
            ),
    );
  }

  Widget _dueItem(String name, String phone, String amount, String status) {
    Color statusColor = status == 'Overdue' ? Colors.redAccent : (status == 'Due Today' ? const Color(0xFFE59A2F) : const Color(0xFF4B5563));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: const Color(0xFFFFF4E2), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(name[0].toUpperCase(), style: GoogleFonts.poppins(color: const Color(0xFFE59A2F), fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF171A1F))), Text(phone, style: const TextStyle(color: Color(0xFF747B84), fontSize: 11))])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(amount, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF20252B))), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(loc.translate(status), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)))]),
      ]),
    );
  }

  Widget _donutChartDues(double overdue, double today, double upcoming, double totalDue) {
    return _donutBase(
      controller: _dueAnimationController,
      total: overdue + today + upcoming,
      values: [overdue, today, upcoming],
      colors: [Colors.redAccent, const Color(0xFFE59A2F), const Color(0xFF4B5563)],
      label: loc.translate('Total Due'),
      centerValue: _money(totalDue),
    );
  }

  Widget _donutChartPayments(double collected, double due) {
    return _donutBase(
      controller: _paymentsAnimationController,
      total: collected + due,
      values: [collected, due],
      colors: [const Color(0xFF4F8A68), Colors.redAccent],
      label: loc.translate('Payments'),
      centerValue: _money(collected),
    );
  }

  Widget _donutBase({
    required AnimationController controller,
    required double total,
    required List<double> values,
    required List<Color> colors,
    required String label,
    required String centerValue,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double t = controller.value;

        // Phase 1 (Sweep): 0.0 -> 0.54 (0ms -> 650ms): 0% to 100% full sweep
        // Phase 2 (Settle): 0.54 -> 1.0 (650ms -> 1200ms): 100% to exact multi-segment proportions (X / Y / Z)
        
        List<PieChartSectionData> sections;

        if (total <= 0) {
          // Zero Data: Neutral ring performs sweep & settle
          if (t <= 0.54) {
            final p1 = Curves.easeOutCubic.transform((t / 0.54).clamp(0.0, 1.0));
            final sweepVal = p1 * 100.0;
            sections = [
              PieChartSectionData(color: const Color(0xFFE59A2F), value: sweepVal > 0 ? sweepVal : 0.001, radius: 12, showTitle: false),
              PieChartSectionData(color: const Color(0xFFE7E9ED), value: (100.0 - sweepVal) > 0 ? (100.0 - sweepVal) : 0.001, radius: 12, showTitle: false),
            ];
          } else {
            final p2 = Curves.easeOutCubic.transform(((t - 0.54) / 0.46).clamp(0.0, 1.0));
            final settleVal = (1.0 - p2) * 100.0;
            sections = [
              if (settleVal > 0.01)
                PieChartSectionData(color: const Color(0xFFE59A2F), value: settleVal, radius: 12, showTitle: false),
              PieChartSectionData(color: const Color(0xFFE7E9ED), value: (100.0 - settleVal) > 0 ? (100.0 - settleVal) : 100.0, radius: 12, showTitle: false),
            ];
          }
        } else {
          // Real Multi-Segment Data (Overdue / Today / Upcoming / Collected)
          if (t <= 0.54) {
            // Phase 1: 0% -> 100% Full Circle Sweep
            final p1 = Curves.easeOutCubic.transform((t / 0.54).clamp(0.0, 1.0));
            final sweepVal = p1 * total;
            final remaining = total - sweepVal;

            sections = [
              PieChartSectionData(color: const Color(0xFFE59A2F), value: sweepVal > 0 ? sweepVal : 0.001, radius: 12, showTitle: false),
              PieChartSectionData(color: const Color(0xFFE7E9ED), value: remaining > 0 ? remaining : 0.001, radius: 12, showTitle: false),
            ];
          } else {
            // Phase 2: 100% -> Exact Multi-Segment Proportions (X / Y / Z)
            final p2 = Curves.easeOutCubic.transform(((t - 0.54) / 0.46).clamp(0.0, 1.0));
            final overlayVal = (1.0 - p2) * total;

            sections = [
              if (overlayVal > 0.01)
                PieChartSectionData(color: const Color(0xFFE59A2F), value: overlayVal, radius: 12, showTitle: false),
              ...values.asMap().entries.map((e) {
                final realVal = e.value > 0 ? e.value * p2 : 0.001;
                return PieChartSectionData(color: colors[e.key], value: realVal, radius: 12, showTitle: false);
              }),
            ];
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 125,
              height: 125,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 42,
                  sections: sections,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF747B84), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  centerValue,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildResponsiveRow(List<Widget> children) => LayoutBuilder(builder: (context, constraints) {
    if (constraints.maxWidth > 650) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children.map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: w))).toList());
    return Column(children: children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)).toList());
  });

  Widget _summaryCard(String title, Widget content) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE7E9ED)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF20252B))), const SizedBox(height: 18), content]),
  );

  Widget _summaryRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF747B84), fontSize: 13, fontWeight: FontWeight.w500))),
      Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF171A1F))),
    ]),
  );
}
