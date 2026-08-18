import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'package:s_link/features/pos/repositories/pos_repository.dart';
import 'package:s_link/features/pos/screens/scanner_screen.dart';
import 'package:s_link/utils/snackbar_utils.dart';
import 'package:uuid/uuid.dart';

/// This screen deliberately creates only a PO draft; stock and product prices
/// are changed later by an authorised user on POS Desktop.
class StockReceiveScreen extends StatefulWidget {
  const StockReceiveScreen({super.key});

  @override
  State<StockReceiveScreen> createState() => _StockReceiveScreenState();
}

class _StockReceiveScreenState extends State<StockReceiveScreen> {
  final _supplierController = TextEditingController();
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _repo = PosRepository();
  final _lines = <_DraftLine>[];
  final _suggestions = <PosProduct>[];
  final _supplierSuggestions = <Map<String, dynamic>>[];
  bool _isLoading = false;
  Timer? _searchDebounce;
  Timer? _supplierDebounce;
  String? _submissionId;
  int? _supplierId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _supplierController.dispose();
    _focusNode.dispose();
    _searchDebounce?.cancel();
    _supplierDebounce?.cancel();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _findOrAdd(String query) async {
    final text = query.trim();
    if (text.isEmpty) return;
    _searchController.clear();
    setState(() => _isLoading = true);
    try {
      final results = await _repo.getAllProducts(searchTerm: text);
      final exact = results.where((product) =>
          product.barcode == text || product.barcode.endsWith(text));
      if (exact.isNotEmpty) {
        _addProduct(exact.first);
      } else if (results.isEmpty) {
        _addFreeform(text);
      } else if (results.length == 1) {
        _addProduct(results.first);
      } else {
        setState(() {
          _suggestions
            ..clear()
            ..addAll(results);
        });
      }
    } catch (_) {
      if (mounted) _addFreeform(text);
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _focusNode.requestFocus();
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final text = query.trim();
    if (text.isEmpty) {
      setState(_suggestions.clear);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await _repo.getAllProducts(searchTerm: text);
      if (!mounted || _searchController.text.trim() != text) return;
      setState(() {
        _suggestions
          ..clear()
          ..addAll(results);
      });
    });
  }

  void _selectSuggestion(PosProduct product) {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(_suggestions.clear);
    _addProduct(product);
    _focusNode.requestFocus();
  }

  void _onSupplierChanged(String query) {
    _supplierDebounce?.cancel();
    _supplierId = null;
    final text = query.trim();
    if (text.isEmpty) {
      setState(_supplierSuggestions.clear);
      return;
    }
    _supplierDebounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await _repo.getSuppliers(searchTerm: text);
      if (!mounted || _supplierController.text.trim() != text) return;
      setState(() {
        _supplierSuggestions
          ..clear()
          ..addAll(results);
      });
    });
  }

  void _selectSupplier(Map<String, dynamic> supplier) {
    final id = int.tryParse(supplier['id']?.toString() ?? '');
    if (id == null) return;
    _supplierDebounce?.cancel();
    _supplierController.text = supplier['name']?.toString() ?? '';
    setState(() {
      _supplierId = id;
      _supplierSuggestions.clear();
    });
    _focusNode.requestFocus();
  }

  void _addProduct(PosProduct product) {
    final existing =
        _lines.where((line) => line.productId == product.id).firstOrNull;
    if (existing != null) {
      existing.qty.text = _format4(existing.quantity + 1);
      existing.fromQuantity();
      setState(() {});
      return;
    }
    setState(() => _lines.insert(
        0, _DraftLine(productId: product.id, name: product.name)));
  }

  void _addFreeform([String name = '']) =>
      setState(() => _lines.insert(0, _DraftLine(name: name)));

  Future<void> _saveDraft() async {
    if (_lines.isEmpty) return;
    if (_supplierId == null) {
      SnackbarUtils.showLeft(context, 'กรุณาเลือกผู้ขายจากรายการ',
          isError: true);
      return;
    }
    final payload = <Map<String, dynamic>>[];
    for (final line in _lines) {
      final error = line.validationError;
      if (error != null) {
        SnackbarUtils.showLeft(context, error, isError: true);
        return;
      }
      payload.add(line.toJson());
    }
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('บันทึกเป็นร่างใบสั่งซื้อ'),
              content: const Text(
                  'รายการนี้จะยังไม่เพิ่มสต็อกและไม่เปลี่ยนราคาสินค้า สามารถไปตรวจและรับของจริงบน POS ได้ภายหลัง'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('ยกเลิก')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('บันทึกร่าง'))
              ],
            ));
    if (confirm != true || !mounted) return;
    setState(() => _isLoading = true);
    _submissionId ??= const Uuid().v4();
    try {
      final result = await _repo.createPurchaseOrderDraft(
        receiptId: _submissionId!,
        supplierId: _supplierId!,
        items: payload,
      );
      if (!mounted) return;
      final id = result['purchaseOrderId'];
      SnackbarUtils.showLeft(context, '✅ บันทึกร่างใบสั่งซื้อ #$id แล้ว');
      for (final line in _lines) {
        line.dispose();
      }
      setState(() {
        _lines.clear();
        _submissionId = null;
        _supplierId = null;
        _supplierController.clear();
      });
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(
            context, 'ส่งร่างไม่สำเร็จ กดบันทึกซ้ำได้อย่างปลอดภัย',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('ร่างใบรับสินค้า'),
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                TextField(
                  controller: _supplierController,
                  onChanged: _onSupplierChanged,
                  decoration: InputDecoration(
                    labelText: 'ผู้ขาย *',
                    hintText: 'พิมพ์เพื่อค้นหาและเลือกผู้ขาย',
                    prefixIcon: const Icon(Icons.storefront_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: _supplierId == null
                        ? null
                        : const Icon(Icons.check_circle, color: Colors.green),
                  ),
                ),
                if (_supplierSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _supplierSuggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final supplier = _supplierSuggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.storefront_outlined),
                          title: Text(supplier['name']?.toString() ?? ''),
                          onTap: () => _selectSupplier(supplier),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  onChanged: _onSearchChanged,
                  onSubmitted: _findOrAdd,
                  decoration: InputDecoration(
                      labelText: 'ชื่อสินค้า หรือรหัสสินค้า',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: () async {
                            final code = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ScannerScreen()));
                            if (code is String) _findOrAdd(code);
                          })),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 224),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final product = _suggestions[index];
                        return ListTile(
                          dense: true,
                          title: Text(product.name),
                          subtitle: Text(product.barcode),
                          onTap: () => _selectSuggestion(product),
                        );
                      },
                    ),
                  ),
              ])),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
              child: _lines.isEmpty
                  ? const Center(
                      child:
                          Text('พิมพ์ชื่อ/รหัสสินค้า หรือสแกนเพื่อเพิ่มรายการ'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _lines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _lineCard(_lines[index]),
                    )),
          if (_lines.isNotEmpty)
            SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                            onPressed: _isLoading ? null : _saveDraft,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                                'บันทึกร่าง (${_lines.length} รายการ)'))))),
        ]),
        floatingActionButton: FloatingActionButton.small(
            onPressed: () => _addFreeform(),
            tooltip: 'เพิ่มชื่อสินค้าเอง',
            child: const Icon(Icons.add)),
      );

  Widget _lineCard(_DraftLine line) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: line.name,
                      decoration: InputDecoration(
                          labelText: line.productId == null
                              ? 'ชื่อสินค้า (ต้องตรวจบน POS)'
                              : 'สินค้า',
                          border: const OutlineInputBorder()),
                      onChanged: (_) => setState(() {}))),
              IconButton(
                  onPressed: () => setState(() {
                        line.dispose();
                        _lines.remove(line);
                      }),
                  icon: const Icon(Icons.delete_outline, color: Colors.red))
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _numberField('จำนวน', line.qty, line.fromQuantity)),
              const SizedBox(width: 8),
              Expanded(
                  child: _numberField('ทุน/หน่วย', line.cost, line.fromCost)),
              const SizedBox(width: 8),
              Expanded(
                  child: _numberField('รวม', line.total, line.fromTotal,
                      decimals: 2)),
            ]),
            if (line.productId == null)
              const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'รายการใหม่: ต้องจับคู่หรือสร้างสินค้าบน POS ก่อนรับเข้า',
                          style:
                              TextStyle(fontSize: 12, color: Colors.orange)))),
          ])));

  Widget _numberField(String label, TextEditingController controller,
          VoidCallback onChanged,
          {int decimals = 4}) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}'))
        ],
        onChanged: (_) {
          onChanged();
          setState(() {});
        },
        decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true),
      );
}

class _DraftLine {
  _DraftLine({this.productId, String name = ''})
      : name = TextEditingController(text: name),
        qty = TextEditingController(text: '1'),
        cost = TextEditingController(),
        total = TextEditingController();
  final int? productId;
  final TextEditingController name, qty, cost, total;
  double get quantity => double.tryParse(qty.text) ?? 0;
  double get unitCost => double.tryParse(cost.text) ?? 0;
  double get lineTotal => double.tryParse(total.text) ?? 0;
  void fromQuantity() {
    if (unitCost > 0) total.text = _format2(quantity * unitCost);
  }

  void fromCost() {
    if (quantity > 0) total.text = _format2(quantity * unitCost);
  }

  void fromTotal() {
    if (quantity > 0) {
      cost.text = _format4(lineTotal / quantity);
    }
  }

  String? get validationError {
    if (name.text.trim().isEmpty) {
      return 'กรุณาระบุชื่อสินค้าทุกรายการ';
    }
    if (quantity <= 0 || unitCost <= 0 || lineTotal <= 0) {
      return 'จำนวน ทุน และยอดรวมต้องมากกว่า 0';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        if (productId != null) 'productId': productId,
        'productName': name.text.trim(),
        'quantity': double.parse(_format4(quantity)),
        'costPrice': double.parse(_format4(unitCost)),
        'total': double.parse(_format2(lineTotal)),
      };
  void dispose() {
    name.dispose();
    qty.dispose();
    cost.dispose();
    total.dispose();
  }
}

String _format4(double value) => value
    .toStringAsFixed(4)
    .replaceFirst(RegExp(r'(?<=\.\d*?)0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');
String _format2(double value) => value.toStringAsFixed(2);

extension on Iterable<_DraftLine> {
  _DraftLine? get firstOrNull => isEmpty ? null : first;
}
