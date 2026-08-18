class StockCheckTemplateItem {
  final String id;
  final String name;
  final String unit;
  final bool enabled;
  final int order;

  const StockCheckTemplateItem(
      {required this.id,
      required this.name,
      required this.unit,
      required this.enabled,
      required this.order});

  factory StockCheckTemplateItem.fromJson(Map<String, dynamic> json) =>
      StockCheckTemplateItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        unit: json['unit']?.toString() ?? 'หน่วย',
        enabled: json['enabled'] == true,
        order: (json['order'] as num?)?.toInt() ?? 0,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'enabled': enabled,
        'order': order
      };
}

class StockCheckTemplate {
  final int revision;
  final List<StockCheckTemplateItem> items;
  const StockCheckTemplate({required this.revision, required this.items});
  factory StockCheckTemplate.fromJson(Map<String, dynamic> json) =>
      StockCheckTemplate(
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        items: (json['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) =>
                StockCheckTemplateItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
  Map<String, dynamic> toJson() =>
      {'revision': revision, 'items': items.map((e) => e.toJson()).toList()};
  static const fallback = StockCheckTemplate(revision: 0, items: [
    StockCheckTemplateItem(
        id: 'pole-7m',
        name: 'เสาไฟฟ้า 7ม.',
        unit: 'หน่วย',
        enabled: true,
        order: 0),
    StockCheckTemplateItem(
        id: 'fence-post',
        name: 'เสารั้ว',
        unit: 'หน่วย',
        enabled: true,
        order: 1),
    StockCheckTemplateItem(
        id: 'fence-post-hole',
        name: 'เสารั้วมีรู',
        unit: 'หน่วย',
        enabled: true,
        order: 2),
    StockCheckTemplateItem(
        id: 'support-pole',
        name: 'เสาค้ำ',
        unit: 'หน่วย',
        enabled: true,
        order: 3),
    StockCheckTemplateItem(
        id: 'boundary-pole',
        name: 'เสาหลักแดน',
        unit: 'หน่วย',
        enabled: true,
        order: 4),
    StockCheckTemplateItem(
        id: 'well-cover-60-solid',
        name: 'ฝาวงบ่อ60ซม. ตัน',
        unit: 'หน่วย',
        enabled: true,
        order: 5),
    StockCheckTemplateItem(
        id: 'well-cover-60-small-hole',
        name: 'ฝาวงบ่อ60ซม.รูเล็ก',
        unit: 'หน่วย',
        enabled: true,
        order: 6),
    StockCheckTemplateItem(
        id: 'well-cover-80-solid',
        name: 'ฝาวงบ่อ80ซม. ตัน',
        unit: 'หน่วย',
        enabled: true,
        order: 7),
    StockCheckTemplateItem(
        id: 'well-cover-80-small-hole',
        name: 'ฝาวงบ่อ80ซม. รูเล็ก',
        unit: 'หน่วย',
        enabled: true,
        order: 8),
    StockCheckTemplateItem(
        id: 'well-cover-100-solid',
        name: 'ฝาวงบ่อ100ซม. ตัน',
        unit: 'หน่วย',
        enabled: true,
        order: 9),
    StockCheckTemplateItem(
        id: 'well-cover-100-small-hole',
        name: 'ฝาวงบ่อ100ซม.รูเล็ก',
        unit: 'หน่วย',
        enabled: true,
        order: 10),
    StockCheckTemplateItem(
        id: 'well-cover-120-solid',
        name: 'ฝาวงบ่อ120ซม. ตัน',
        unit: 'หน่วย',
        enabled: true,
        order: 11),
    StockCheckTemplateItem(
        id: 'well-cover-120-small-hole',
        name: 'ฝาวงบ่อ120ซม. รูเล็ก',
        unit: 'หน่วย',
        enabled: true,
        order: 12),
  ]);
}
