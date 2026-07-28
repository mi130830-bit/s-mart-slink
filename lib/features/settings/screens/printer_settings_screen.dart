import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:s_link/features/pos/services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _printerService = PrinterService();

  List<Printer> _printers = [];
  Printer? _selectedReceiptPrinter;
  Printer? _selectedInvoicePrinter;
  bool _autoPrint = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // 1. List Printers
      List<Printer> printers = [];
      try {
        printers = await Printing.listPrinters();
      } catch (e) {
        debugPrint('Printing.listPrinters() not supported on this platform: $e');
      }

      // 2. Load Preferences
      final receiptName = await _printerService.getReceiptPrinterName();
      final invoiceName = await _printerService.getInvoicePrinterName();
      final autoPrint = await _printerService.getAutoPrint();

      Printer? matchPrinter(String? name) {
        if (name == null) return null;
        try {
          return printers.firstWhere((p) => p.name == name);
        } catch (_) {
          // Fallback: Create a dummy printer object to show "Missing: Name"
          final dummy = Printer(name: name, url: name, model: 'Unknown');
          printers.add(dummy);
          return dummy;
        }
      }

      if (mounted) {
        setState(() {
          _printers = printers;
          _selectedReceiptPrinter = matchPrinter(receiptName);
          _selectedInvoicePrinter = matchPrinter(invoiceName);
          _autoPrint = autoPrint;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading printer settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarUtils.showLeft(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _save() async {
    await _printerService.saveReceiptPrinter(_selectedReceiptPrinter);
    await _printerService.saveInvoicePrinter(_selectedInvoicePrinter);
    await _printerService.saveAutoPrint(_autoPrint);

    if (mounted) {
      SnackbarUtils.showLeft(context, 'บันทึกการตั้งค่าแล้ว');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่าเครื่องพิมพ์ (Printer)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('เลือกเครื่องพิมพ์สำหรับ Mini POS',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 20),
                  _buildDropdown(
                    label: 'เครื่องพิมพ์ใบเสร็จ (80mm)',
                    value: _selectedReceiptPrinter,
                    items: _printers,
                    onChanged: (p) =>
                        setState(() => _selectedReceiptPrinter = p),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'เครื่องพิมพ์ใบส่งของ (A5)',
                    value: _selectedInvoicePrinter,
                    items: _printers,
                    onChanged: (p) =>
                        setState(() => _selectedInvoicePrinter = p),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text(
                        'พิมพ์ใบเสร็จอัตโนมัติ (Auto Print Receipt)'),
                    subtitle: const Text('เมื่อชำระเงินสำเร็จ'),
                    value: _autoPrint,
                    onChanged: (val) => setState(() => _autoPrint = val),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('บันทึกการตั้งค่า',
                        style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required Printer? value,
    required List<Printer> items,
    required ValueChanged<Printer?> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButton<Printer>(
              isExpanded: true,
              value: items.contains(value) ? value : null, // Safety check
              hint: Text(value?.name ??
                  'เลือกเครื่องพิมพ์...'), // Show saved name even if not in list
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('(ไม่ระบุ - เลือกตอนพิมพ์)')),
                ...items.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
