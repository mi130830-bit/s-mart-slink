import 'dart:async';
import 'package:flutter/material.dart';
import 'package:s_link/features/pos/models/pos_customer.dart';
import 'package:s_link/features/pos/repositories/pos_repository.dart';

class CustomerSearchDialog extends StatefulWidget {
  final PosRepository repo;
  const CustomerSearchDialog({super.key, required this.repo});

  @override
  State<CustomerSearchDialog> createState() => _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends State<CustomerSearchDialog> {
  final _searchController = TextEditingController();
  List<PosCustomer> _customers = [];
  bool _isLoading = false;
  Timer? _debounce;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(String term) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      if (term.isEmpty) {
        setState(() => _customers = []);
        return;
      }
      setState(() => _isLoading = true);
      try {
        final results = await widget.repo.searchCustomers(term);
        if (mounted) setState(() => _customers = results);
      } catch (e) {
        debugPrint('Search error: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 📱 Check if Tablet (shortest side > 600)
    final bool isTablet = MediaQuery.of(context).size.shortestSide > 600;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 500 : double.infinity,
          maxHeight: isTablet ? 600 : double.infinity,
        ),
        child: Dialog(
          insetPadding: isTablet
              ? const EdgeInsets.all(24)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.people_alt_outlined,
                        color: Theme.of(context).primaryColor,
                        size: isTablet ? 24 : 28),
                    const SizedBox(width: 12),
                    Text(
                      'เลือกลูกค้า (Select Customer)',
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Search Box
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อ, ชื่อเล่น, หรือเบอร์โทร...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: isTablet
                        ? const EdgeInsets.symmetric(vertical: 12)
                        : const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: _search,
                  autofocus: true,
                  style: TextStyle(fontSize: isTablet ? 16 : 18),
                ),
              ),

              // Results List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _customers.isEmpty
                        ? Center(
                            child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                  _searchController.text.isEmpty
                                      ? 'พิมพ์เพื่อค้นหาลูกค้า'
                                      : 'ไม่พบข้อมูลลูกค้า',
                                  style: const TextStyle(color: Colors.grey)),
                            ],
                          ))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _customers.length,
                            separatorBuilder: (ctx, i) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final c = _customers[index];
                              return _buildCustomerItem(c, isTablet);
                            },
                          ),
              ),

              // Footer Actions
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                      ),
                      child: Text('ยกเลิก',
                          style: TextStyle(fontSize: isTablet ? 14 : 16)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Return null to allow parent to handle "Clear" or "General"
                        // Parent needs to distinguish between "Back" (no change) and "General" (clear)
                        // But usually "General" means set customer to null.
                        // To be safe, we can return a specific value or handle it in parent.
                        // For now, returning null is ambiguous (cancel vs clear).
                        // Let's assume the parent treats `null` as cancel, and we need another way?
                        // Actually, in `cart_screen` logic:
                        // `if (customer == null)` -> checks logic.
                        // Let's standard: return `null` for cancel.
                        // But how to select "General"?
                        // We can pass a special flag or object.
                        // Or we can just have a callback?

                        // Fix: return explicit null to clear?
                        // For now, let's assume CartScreen handles "General" by setting null.
                        Navigator.pop(context, 'CLEAR');
                      },
                      icon: Icon(Icons.person_off, size: isTablet ? 18 : 20),
                      label: Text('ลูกค้าทั่วไป (General)',
                          style: TextStyle(fontSize: isTablet ? 14 : 16)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerItem(PosCustomer c, bool isTablet) {
    // 🧹 Data Cleanup Logic
    final String displayName = c.fullName;
    final String displayPhone = c.phoneNumber ?? '-';
    // Check if name is just the phone number (Data issue)
    final bool isNameSameAsPhone =
        displayName.replaceAll(' ', '') == displayPhone.replaceAll(' ', '') ||
            displayName.trim() == displayPhone.trim();

    // Determine what to show
    String title = displayName;
    if (title.isEmpty || isNameSameAsPhone) {
      title = 'ลูกค้า (Customer)';
      if (c.nickname != null && c.nickname!.isNotEmpty) {
        title += ' (${c.nickname})';
      }
    }

    return ListTile(
      visualDensity: isTablet ? VisualDensity.compact : VisualDensity.standard,
      contentPadding:
          EdgeInsets.symmetric(horizontal: 16, vertical: isTablet ? 0 : 4),
      leading: CircleAvatar(
        radius: isTablet ? 18 : 24,
        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        child: Icon(Icons.person,
            color: Theme.of(context).primaryColor, size: isTablet ? 20 : 28),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 15 : 17,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (c.code != null && c.code!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Text(
                c.code!,
                style: TextStyle(
                    fontSize: isTablet ? 10 : 12, color: Colors.blue.shade800),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.phone, size: isTablet ? 12 : 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                displayPhone,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: isTablet ? 13 : 15,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (c.address != null && c.address!.isNotEmpty)
            Text(
              c.address!,
              style: TextStyle(
                  fontSize: isTablet ? 11 : 13, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      onTap: () => Navigator.pop(context, c),
    );
  }
}
