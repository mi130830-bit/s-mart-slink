import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:s_link/features/shop_log/models/stock_check_template.dart';
import 'package:s_link/features/shop_log/services/stock_check_template_service.dart';

class StockCheckTemplateEditorScreen extends StatefulWidget {
  const StockCheckTemplateEditorScreen({super.key});
  @override
  State<StockCheckTemplateEditorScreen> createState() =>
      _StockCheckTemplateEditorScreenState();
}

class _StockCheckTemplateEditorScreenState
    extends State<StockCheckTemplateEditorScreen> {
  final _service = StockCheckTemplateService();
  final _uuid = const Uuid();
  late StockCheckTemplate _template;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _template = await _service.load();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _replace(List<StockCheckTemplateItem> items) => setState(() =>
      _template = StockCheckTemplate(revision: _template.revision, items: [
        for (var i = 0; i < items.length; i++)
          StockCheckTemplateItem(
              id: items[i].id,
              name: items[i].name,
              unit: items[i].unit,
              enabled: items[i].enabled,
              order: i)
      ]));
  Future<void> _edit([StockCheckTemplateItem? existing]) async {
    final name = TextEditingController(text: existing?.name);
    final unit = TextEditingController(text: existing?.unit ?? 'หน่วย');
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: Text(existing == null ? 'เพิ่มรายการ' : 'แก้ไขรายการ'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'ชื่อรายการ')),
                  TextField(
                      controller: unit,
                      decoration: const InputDecoration(labelText: 'หน่วย'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ยกเลิก')),
                  FilledButton(
                      onPressed: () {
                        if (name.text.trim().isNotEmpty &&
                            unit.text.trim().isNotEmpty) {
                          Navigator.pop(context, true);
                        }
                      },
                      child: const Text('ตกลง'))
                ]));
    if (saved != true) {
      return;
    }
    final items = [..._template.items];
    final normalized =
        name.text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    if (items.any((x) =>
        x.id != existing?.id &&
        x.name.replaceAll(RegExp(r'\s+'), ' ').toLowerCase() == normalized)) {
      setState(() => _error = 'ชื่อรายการซ้ำ');
      return;
    }
    final next = StockCheckTemplateItem(
        id: existing?.id ?? _uuid.v4(),
        name: name.text.trim(),
        unit: unit.text.trim(),
        enabled: existing?.enabled ?? true,
        order: existing?.order ?? items.length);
    final index =
        existing == null ? -1 : items.indexWhere((x) => x.id == existing.id);
    if (index < 0) {
      items.add(next);
    } else {
      items[index] = next;
    }
    _replace(items);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      _template = await _service.save(_template);
      _error = null;
    } catch (e) {
      _error = 'บันทึกไม่สำเร็จ: $e';
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('แบบตรวจนับสต๊อก'), actions: [
        IconButton(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            tooltip: 'เพิ่มรายการ')
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red))),
              Expanded(
                  child: ReorderableListView.builder(
                      itemCount: _template.items.length,
                      onReorder: (oldIndex, newIndex) {
                        final items = [..._template.items];
                        if (newIndex > oldIndex) newIndex--;
                        final item = items.removeAt(oldIndex);
                        items.insert(newIndex, item);
                        _replace(items);
                      },
                      itemBuilder: (_, i) {
                        final item = _template.items[i];
                        return ListTile(
                            key: ValueKey(item.id),
                            leading: const Icon(Icons.drag_handle),
                            title: Text(item.name),
                            subtitle: Text(item.unit),
                            onTap: () => _edit(item),
                            trailing: Switch(
                                value: item.enabled,
                                onChanged: (enabled) {
                                  final items = [..._template.items];
                                  items[i] = StockCheckTemplateItem(
                                      id: item.id,
                                      name: item.name,
                                      unit: item.unit,
                                      enabled: enabled,
                                      order: item.order);
                                  _replace(items);
                                }));
                      })),
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                      onPressed: _save, child: const Text('บันทึก')))
            ]));
}
