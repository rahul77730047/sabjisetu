import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key, required this.api});
  final ApiClient api;

  Future<void> _exportCsv(BuildContext context, String title, String resource) async {
    try {
      final list = await api.list(resource);
      if (list.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No $title records to export.')));
        }
        return;
      }

      final keys = list.first.keys.where((k) => k != 'id' && k != 'created_at' && k != 'updated_at').toList();
      final buffer = StringBuffer();
      buffer.writeln(keys.join(','));

      for (final row in list) {
        final line = keys.map((k) {
          final val = row[k]?.toString().replaceAll('"', '""') ?? '';
          return '"$val"';
        }).join(',');
        buffer.writeln(line);
      }

      final csvContent = buffer.toString();
      final uri = Uri.dataFromString(
        csvContent,
        mimeType: 'text/csv',
        encoding: utf8,
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${list.length} $title records.')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE7E9ED)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE59A2F).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.backup_outlined, size: 48, color: Color(0xFFE59A2F)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Backup & Export Data',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF171A1F),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Export your complete business data (Transactions, Stock, Customers, Settings) as JSON or CSV reports.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF747B84), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 28),

                // Full JSON Export Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('${api.baseUrl}/backup/export');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open backup URL')));
                        }
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text('Export Complete JSON Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF20252B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Color(0xFFE7E9ED))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Individual CSV Reports', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF747B84))),
                      ),
                      Expanded(child: Divider(color: Color(0xFFE7E9ED))),
                    ],
                  ),
                ),

                // Module CSV Buttons Grid
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _csvBtn(context, 'Mandi Purchases', 'mandi-purchases', Icons.shopping_basket_outlined),
                    _csvBtn(context, 'Local Purchases', 'local-purchases', Icons.store_outlined),
                    _csvBtn(context, 'Stock / Inventory', 'stock', Icons.inventory_2_outlined),
                    _csvBtn(context, 'Sales / Supply', 'sales', Icons.local_shipping_outlined),
                    _csvBtn(context, 'Customers', 'customers', Icons.people_outline),
                    _csvBtn(context, 'Expenses', 'expenses', Icons.receipt_long_outlined),
                    _csvBtn(context, 'Labour', 'labour', Icons.engineering_outlined),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _csvBtn(BuildContext context, String label, String resource, IconData icon) {
    return OutlinedButton.icon(
      onPressed: () => _exportCsv(context, label, resource),
      icon: Icon(icon, size: 16, color: const Color(0xFFE59A2F)),
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF171A1F))),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE7E9ED)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}
