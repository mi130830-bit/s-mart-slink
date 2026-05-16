import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';

class PrinterService {
  static const String keyReceiptPrinter = 'printer_receipt';
  static const String keyInvoicePrinter = 'printer_invoice';
  static const String keyAutoPrint = 'printer_auto_print';

  Future<void> saveReceiptPrinter(Printer? printer) async {
    final prefs = await SharedPreferences.getInstance();
    if (printer != null) {
      await prefs.setString(
          keyReceiptPrinter, printer.name); // Store name as ID
      // Optionally store URL if needed for network printers, but name is usually enough for local
    } else {
      await prefs.remove(keyReceiptPrinter);
    }
  }

  Future<void> saveInvoicePrinter(Printer? printer) async {
    final prefs = await SharedPreferences.getInstance();
    if (printer != null) {
      await prefs.setString(keyInvoicePrinter, printer.name);
    } else {
      await prefs.remove(keyInvoicePrinter);
    }
  }

  Future<void> saveAutoPrint(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyAutoPrint, value);
  }

  Future<String?> getReceiptPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyReceiptPrinter);
  }

  Future<String?> getInvoicePrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyInvoicePrinter);
  }

  Future<bool> getAutoPrint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyAutoPrint) ?? false;
  }
}
