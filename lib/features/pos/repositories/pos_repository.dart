import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:s_link/features/pos/models/pos_customer.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';

class PosRepository {
  // Removed MySQLService dependency
  // final MySQLService _db = MySQLService();
  final PosApiService _api = PosApiService();

  Future<List<PosCustomer>> searchCustomers(String term) async {
    // 1. API Only (Tunnel)
    try {
      debugPrint('🔄 Searching Customers via API Tunnel...');
      return await _api.searchCustomers(term);
    } catch (e) {
      debugPrint('❌ API Search Customers Failed: $e');
      return [];
    }
  }

  Future<List<PosProduct>> getAllProducts({String searchTerm = ''}) async {
    // 1. API Only (Tunnel)
    try {
      debugPrint('🔄 Fetching Products via API Tunnel...');
      return await _api.getProducts(search: searchTerm, limit: 100);
    } catch (e) {
      debugPrint('❌ API Fetch Products Failed: $e');
      return [];
    }
  }

  Future<String?> uploadProductImage(int productId, File imageFile) =>
      _api.uploadProductImage(productId: productId, imageFile: imageFile);

  Future<int> createOrder({
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String paymentMethod = 'CASH',
    int? customerId,
    String? note,
    int? userId = 1, // Default to 1 (Admin) if not provided
  }) async {
    // 1. API Only (Tunnel)
    try {
      debugPrint('🔄 Creating Order via API Tunnel...');

      // ✅ แก้ไขกลับ: POS Desktop ต้องการ status เป็น COMPLETED เสมอเพื่อให้แสดงในประวัติ
      // การเป็นหนี้จะดูจาก paymentMethod = 'CREDIT' แทน
      final orderStatus = 'COMPLETED';

      final result = await _api.createOrder({
        'customerId':
            (customerId == null || customerId == 0) ? null : customerId,
        'total': totalAmount,
        'grandTotal': totalAmount, // Simple logic
        'paymentMethod': paymentMethod,
        'items': items,
        'userId': userId, // Pass userId
        'status': orderStatus, // ✅ ไม่ Force COMPLETED อีกต่อไป
      }, note: note); // Pass Note
      return int.tryParse(result['orderId'].toString()) ?? 0;
    } catch (e) {
      debugPrint('❌ API Create Order Failed: $e');
      return 0;
    }
  }

  /// Uses the server-authoritative checkout path.  Do not add prices, totals,
  /// discounts or VAT to this payload; the POS server calculates them.
  Future<Map<String, dynamic>> createAuthoritativeCheckout({
    required String clientRequestId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required double receivedAmount,
    int? customerId,
    int pointsUsed = 0,
    String? couponCode,
  }) {
    return _api.postRaw('/mobile-checkout/', {
      'clientRequestId': clientRequestId,
      'items': items,
      'customerId': customerId,
      'paymentMethod': paymentMethod,
      'receivedAmount': receivedAmount,
      'pointsUsed': pointsUsed,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
    });
  }

  Future<Map<String, dynamic>> getAuthoritativeCheckoutQuote({
    required List<Map<String, dynamic>> items,
    int? customerId,
    int pointsUsed = 0,
    String? couponCode,
  }) =>
      _api.postRaw('/mobile-checkout/quote', {
        'items': items,
        'customerId': customerId,
        'pointsUsed': pointsUsed,
        if (couponCode != null && couponCode.isNotEmpty)
          'couponCode': couponCode,
      });

  Future<bool> updateStock(
    List<Map<String, dynamic>> items, {
    String? user,
    String? note,
  }) async {
    // 1. API Only (Tunnel)
    try {
      debugPrint('🔄 Updating Stock via API Tunnel...');
      for (var item in items) {
        await _api.adjustStock(
          productId: item['productId'],
          newQuantity: (item['newStock'] as num).toDouble(),
          note: note ?? 'S-Link Stock Check (API)',
          user: user ?? 'App User',
        );
      }
      return true;
    } catch (e) {
      debugPrint('❌ API Update Stock Failed: $e');
      return false;
    }
  }

  Future<bool> addStock(
    List<Map<String, dynamic>> items, {
    String? user,
    String? note,
  }) async {
    // 1. API Only (Tunnel)
    try {
      debugPrint('🔄 Adding Stock via API Tunnel...');
      for (var item in items) {
        await _api.increaseStock(
          productId: item['productId'],
          quantity: (item['quantity'] as num).toDouble(),
          note: note ?? 'S-Link Stock In (API)',
          user: user ?? 'App User',
        );
      }
      return true;
    } catch (e) {
      debugPrint('❌ API Add Stock Failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> createPurchaseOrderDraft({
    required String receiptId,
    required int supplierId,
    required List<Map<String, dynamic>> items,
  }) =>
      _api.createPurchaseOrderDraft(
        receiptId: receiptId,
        supplierId: supplierId,
        items: items,
      );

  Future<List<Map<String, dynamic>>> getSuppliers({String searchTerm = ''}) =>
      _api.getSuppliers(search: searchTerm);
}
