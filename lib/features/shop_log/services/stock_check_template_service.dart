import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';
import '../models/stock_check_template.dart';

class StockCheckTemplateService {
  static const _cacheKey = 'stock_check_template_v1_cache';
  final PosApiService _api;
  StockCheckTemplateService({PosApiService? api})
      : _api = api ?? PosApiService();

  Future<StockCheckTemplate> load() async {
    try {
      final data = await _api.getStockCheckTemplate();
      final template =
          StockCheckTemplate.fromJson(Map<String, dynamic>.from(data));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(template.toJson()));
      return template;
    } catch (_) {
      final cached =
          (await SharedPreferences.getInstance()).getString(_cacheKey);
      if (cached != null) {
        return StockCheckTemplate.fromJson(jsonDecode(cached));
      }
      return StockCheckTemplate.fallback;
    }
  }

  Future<StockCheckTemplate> save(StockCheckTemplate template) async {
    final data = await _api.saveStockCheckTemplate(
        template.revision, template.items.map((e) => e.toJson()).toList());
    final saved = StockCheckTemplate.fromJson(Map<String, dynamic>.from(data));
    await (await SharedPreferences.getInstance())
        .setString(_cacheKey, jsonEncode(saved.toJson()));
    return saved;
  }
}
