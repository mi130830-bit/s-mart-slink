import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/pos/screens/cart_screen.dart';
import 'package:s_link/features/pos/screens/price_check_screen.dart';
import 'package:s_link/features/pos/screens/stock_check_screen.dart';
import 'package:s_link/features/pos/screens/stock_receive_screen.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';
import 'package:s_link/features/settings/screens/pos_config_screen.dart';

class ShopMenuScreen extends StatefulWidget {
  const ShopMenuScreen({super.key});

  @override
  State<ShopMenuScreen> createState() => _ShopMenuScreenState();
}

class _ShopMenuScreenState extends State<ShopMenuScreen> {
  Map<String, dynamic>? _summary;
  bool _loadingSummary = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _loadingSummary = true);
    try {
      final data = await PosApiService().getDailySummary();
      if (mounted) setState(() => _summary = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final isAdmin = authProvider.isUserAdmin;
    final moneyFmt = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('หน้าร้าน (Shop)'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชยอดวันนี้',
            onPressed: _loadSummary,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Daily Summary Card ──────────────────────────────
              if (isAdmin) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _loadingSummary
                        ? const Center(
                            child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ))
                        : _summary == null
                            ? const Text('ยอดวันนี้: ไม่สามารถโหลดได้',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'สรุปยอดวันนี้',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.grey.shade700),
                                      ),
                                      Text(
                                        '${_summary!['orderCount']} บิล',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '฿${moneyFmt.format((_summary!['totalSales'] as num).toDouble())}',
                                    style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildPill(
                                        '💵 เงินสด',
                                        moneyFmt.format((_summary!['cashTotal']
                                                as num)
                                            .toDouble()),
                                        Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildPill(
                                        '📋 สินเชื่อ',
                                        moneyFmt.format((_summary!['creditTotal']
                                                as num)
                                            .toDouble()),
                                        Colors.orange,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // ── Menu Buttons ────────────────────────────────────
              _buildMenuButton(
                context,
                title: 'หน้าขาย (POS)',
                icon: Icons.point_of_sale,
                color: Colors.teal,
                onTap: () => _navigateTo(context, const CartScreen()),
              ),
              _buildMenuButton(
                context,
                title: 'เช็คราคา (Price Check)',
                icon: Icons.attach_money,
                color: Colors.orange,
                onTap: () => _navigateTo(context, const PriceCheckScreen()),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 20),
                _buildMenuButton(
                  context,
                  title: 'เช็คสต๊อก (Stock Check)',
                  icon: Icons.inventory,
                  color: const Color(0xFF1E88E5),
                  onTap: () =>
                      _navigateTo(context, const StockCheckScreen()),
                ),
                const SizedBox(height: 20),
                _buildMenuButton(
                  context,
                  title: 'รับของเข้า (Stock In)',
                  icon: Icons.download,
                  color: Colors.green,
                  onTap: () =>
                      _navigateTo(context, const StockReceiveScreen()),
                ),
              ],
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () =>
                    _navigateTo(context, const PosConfigScreen()),
                icon: const Icon(Icons.settings_remote),
                label: const Text('ตั้งค่าเชื่อมต่อ (Config)'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label ฿$value',
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 120,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
        ),
        onPressed: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50),
            const SizedBox(height: 10),
            Text(
              title,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
