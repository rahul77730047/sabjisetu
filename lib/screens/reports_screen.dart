import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_client.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.api});
  final ApiClient api;
  @override State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool loading = true;
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final summary = await widget.api.summary();
      final trend = await widget.api.trend();
      data = { 'summary': summary, 'trend': trend };
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: Color(0xFFE59A2F)));
    if (error != null) return Center(child: Text(error!, style: const TextStyle(color: Colors.redAccent)));

    final s = data?['summary'] as Map<String, dynamic>;
    final t = data?['trend'] as List<dynamic>;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Reports & Analytics',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF171A1F),
            ),
          ),
          const SizedBox(height: 20),
          
          _buildSectionTitle('Financial Overview'),
          LayoutBuilder(builder: (context, constraints) {
            final double cardWidth = (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16, runSpacing: 16,
              children: [
                _card(cardWidth, 'Monthly Sales', '₹${_n(s['sales_month'])}', Icons.trending_up_rounded, const Color(0xFF4F8A68)),
                _card(cardWidth, 'Monthly Purchases', '₹${_n(s['purchases_month'])}', Icons.shopping_cart_outlined, const Color(0xFFE59A2F)),
                _card(cardWidth, 'Monthly Profit', '₹${_n(s['sales_month']) - _n(s['cogs_month'])}', Icons.payments_outlined, const Color(0xFF20252B)),
                _card(cardWidth, 'Stock Value', '₹${_n(s['stock_value'])}', Icons.inventory_2_outlined, const Color(0xFF4B5563)),
              ],
            );
          }),
          
          const SizedBox(height: 28),
          _buildSectionTitle('Recent Trend (Last 7 Days)'),
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE7E9ED))),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  key: const ValueKey('reports_trend_table'),
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFFFF4E2)),
                  columns: [
                    DataColumn(label: Text('Day', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF20252B)))),
                    DataColumn(label: Text('Sales', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF20252B)))),
                    DataColumn(label: Text('Purchase', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF20252B)))),
                  ],
                  rows: t.map((row) => DataRow(cells: [
                    DataCell(Text(row['day'] ?? '', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF171A1F)))),
                    DataCell(Text('₹${_n(row['sales'])}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF4F8A68)))),
                    DataCell(Text('₹${_n(row['purchase'])}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFE59A2F)))),
                  ])).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _n(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
  );

  Widget _card(double width, String label, String value, IconData icon, Color color) => Container(
    width: width,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE7E9ED)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 16),
        Text(label.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF747B84), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F)), overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}
