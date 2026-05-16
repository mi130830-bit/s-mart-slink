import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'package:s_link/features/pos/models/pos_customer.dart';

class PdfDocumentGenerator {
  // --- Helpers ---

  static Future<pw.Font> getFontRegular() async {
    await initializeDateFormatting('th', null);
    try {
      return await PdfGoogleFonts.sarabunRegular();
    } catch (e) {
      return pw.Font.helvetica();
    }
  }

  static Future<pw.Font> getFontBold() async {
    try {
      return await PdfGoogleFonts.sarabunBold();
    } catch (e) {
      return pw.Font.helveticaBold();
    }
  }

  static String _formatMoney(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }

  static String _thaiMonth(String monthStr) {
    int month = int.tryParse(monthStr) ?? 1;
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return monthStr;
  }

  // --- Thermal Receipt (Ported from POS Desktop) ---

  static Future<Uint8List> generateReceipt({
    required int orderId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    PosCustomer? customer,
    String shopName = 'S-Link Mini POS',
    String shopAddress = '',
    String shopPhone = '',
    String cashierName = 'Admin',
  }) async {
    final font = await getFontRegular();
    final fontBold = await getFontBold();

    // POS Desktop Logic: Check format, usually roll80
    final pageFormat = PdfPageFormat.roll80;

    final double bodySize = 9.0;
    final double headerSize = 10.0;
    final double titleSize = 14.0;

    // Date formatting
    final now = DateTime.now();
    final dateParts = DateFormat('dd/MM/yyyy').format(now).split('/');
    final dateThai =
        '${int.parse(dateParts[0])} ${_thaiMonth(dateParts[1])} ${int.parse(dateParts[2]) + 543}';
    final timeStr = DateFormat('HH:mm:ss').format(now);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero, // 80mm uses zero margin
        build: (context) {
          return pw.Center(
            child: pw.Container(
              width: pageFormat.width,
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.center, // Center align for thermal
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // Image logo would go here if available

                  // Document Title
                  pw.Text('ใบเสร็จรับเงินอย่างย่อ',
                      style: pw.TextStyle(font: fontBold, fontSize: titleSize),
                      textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 2),

                  // Shop Name
                  pw.Text(shopName,
                      style: pw.TextStyle(
                          font: fontBold, fontSize: headerSize + 2),
                      textAlign: pw.TextAlign.center),

                  // Address
                  if (shopAddress.isNotEmpty)
                    pw.Text(shopAddress,
                        style: pw.TextStyle(font: font, fontSize: bodySize),
                        textAlign: pw.TextAlign.center),

                  // Phone
                  if (shopPhone.isNotEmpty)
                    pw.Text('โทร $shopPhone',
                        style: pw.TextStyle(font: font, fontSize: bodySize),
                        textAlign: pw.TextAlign.center),

                  pw.SizedBox(height: 4),
                  pw.Divider(thickness: 1),

                  // Customer Info
                  if (customer != null) ...[
                    pw.Container(
                      width: double.infinity,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('ชื่อลูกค้า : ${customer.fullName}',
                              style:
                                  pw.TextStyle(font: font, fontSize: bodySize)),
                          if (customer.address != null &&
                              customer.address!.isNotEmpty)
                            pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('ที่อยู่ : ',
                                      style: pw.TextStyle(
                                          font: font, fontSize: bodySize)),
                                  pw.Expanded(
                                      child: pw.Text(customer.address!,
                                          style: pw.TextStyle(
                                              font: font, fontSize: bodySize)))
                                ]),
                          if (customer.phone != null &&
                              customer.phone!.isNotEmpty)
                            pw.Text('โทร : ${customer.phone}',
                                style: pw.TextStyle(
                                    font: font, fontSize: bodySize)),
                        ],
                      ),
                    ),
                    pw.Divider(thickness: 1),
                  ],

                  // Meta Data
                  pw.Container(
                      width: double.infinity,
                      child: pw.Column(children: [
                        pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                  'เลขที่บิล: ${orderId.toString().padLeft(9, '0')}',
                                  style: pw.TextStyle(
                                      font: font, fontSize: bodySize)),
                              pw.Text('Cashier: $cashierName',
                                  style: pw.TextStyle(
                                      font: font, fontSize: bodySize)),
                            ]),
                        pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('วันที่ : $dateThai',
                                  style: pw.TextStyle(
                                      font: font, fontSize: bodySize)),
                              pw.Text('เวลา : $timeStr',
                                  style: pw.TextStyle(
                                      font: font, fontSize: bodySize)),
                            ]),
                      ])),
                  pw.SizedBox(height: 5),
                  pw.Container(
                      height: 0.5, color: PdfColors.black), // Separator

                  // Table
                  pw.Table(columnWidths: {
                    0: const pw.FlexColumnWidth(4),
                    1: const pw.FlexColumnWidth(0.8),
                    2: const pw.FlexColumnWidth(1.2), // Price
                    3: const pw.FlexColumnWidth(1.3), // Total
                  }, children: [
                    // Header
                    pw.TableRow(children: [
                      _cell('รายการ', fontBold, headerSize,
                          align: pw.TextAlign.left),
                      _cell('จน.', fontBold, headerSize,
                          align: pw.TextAlign.center),
                      _cell('ราคา', fontBold, headerSize,
                          align: pw.TextAlign.right),
                      _cell('รวม', fontBold, headerSize,
                          align: pw.TextAlign.right),
                    ]),
                    pw.TableRow(children: [
                      pw.SizedBox(height: 4),
                      pw.SizedBox(height: 4),
                      pw.SizedBox(height: 4),
                      pw.SizedBox(height: 4)
                    ]),

                    // Items
                    ...items.map((item) {
                      final p = item['product'] as PosProduct;
                      final qty = item['qty'] as int;
                      final price = item['price'] as double;
                      final total = price * qty;

                      return pw.TableRow(children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 1),
                            child: pw.Text(p.name,
                                style: pw.TextStyle(
                                    font: fontBold, fontSize: bodySize))),
                        _cell('$qty', fontBold, bodySize,
                            align: pw.TextAlign.center),
                        _cell(_formatMoney(price), fontBold, bodySize,
                            align: pw.TextAlign.right),
                        _cell(_formatMoney(total), fontBold, bodySize,
                            align: pw.TextAlign.right),
                      ]);
                    }),
                  ]),

                  pw.SizedBox(height: 2),
                  pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                  // Totals
                  pw.Container(
                      width: double.infinity,
                      child: pw.Column(children: [
                        _buildTotalRow('ยอดสุทธิ', _formatMoney(totalAmount),
                            fontBold, bodySize + 4),
                      ])),
                  pw.Divider(thickness: 1),

                  // Footer
                  pw.SizedBox(height: 5),
                  pw.Text('ขอบคุณที่ใช้บริการ',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: bodySize,
                          color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 10),
                  pw.Text("RD:${orderId.toString().padLeft(6, '0')}",
                      style: pw.TextStyle(
                          font: font, fontSize: 8, color: PdfColors.grey500)),

                  pw.SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // --- Delivery Note (Ported from POS Desktop) ---

  static Future<Uint8List> generateDeliveryNote({
    required int orderId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    PosCustomer? customer,
    String? deliveryAddress,
    String shopName = 'S-Link Service',
    String shopAddress = '', // Added
    String shopPhone = '',
  }) async {
    final font = await getFontRegular();
    final fontBold = await getFontBold();

    // POS Desktop Format: 9 x 5.5 inches (approx half letter/A5 wide) or A4
    // POS Desktop Format: A5 (Requested by User)
    final pageFormat = PdfPageFormat.a5;

    // Explicit margins from POS Desktop
    final exactFormat = PdfPageFormat(
      pageFormat.width,
      pageFormat.height,
      marginLeft: 10.0 * PdfPageFormat.mm,
      marginRight: 10.0 * PdfPageFormat.mm,
      marginTop: 10.0 * PdfPageFormat.mm,
      marginBottom: 5.0 * PdfPageFormat.mm,
    );

    final double fontSizeNormal = 10.0;
    final double fontSizeTitle = 16.0;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    pdf.addPage(pw.Page(
        pageFormat: exactFormat,
        build: (context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Top Section
              pw.Column(children: [
                // Header
                pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                            pw.Text(shopName,
                                style:
                                    pw.TextStyle(font: fontBold, fontSize: 14)),
                            if (shopAddress.isNotEmpty)
                              pw.Text(shopAddress,
                                  style: pw.TextStyle(
                                      font: font, fontSize: fontSizeNormal)),
                            if (shopPhone.isNotEmpty)
                              pw.Text('โทร: $shopPhone',
                                  style: pw.TextStyle(
                                      font: font, fontSize: fontSizeNormal)),
                          ])),
                    ]),
                pw.SizedBox(height: 10),
                pw.Center(
                    child: pw.Text('ใบส่งของ',
                        style: pw.TextStyle(
                            font: fontBold, fontSize: fontSizeTitle))),
                pw.SizedBox(height: 10),

                // Info Row
                pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left: Customer
                      pw.Expanded(
                          flex: 6,
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _buildLabelValue(
                                    'ลูกค้า',
                                    customer?.fullName ?? 'ลูกค้าทั่วไป',
                                    font,
                                    fontSizeNormal),
                                _buildLabelValue(
                                    'ที่อยู่',
                                    deliveryAddress ?? customer?.address ?? '-',
                                    font,
                                    fontSizeNormal),
                                _buildLabelValue('โทร', customer?.phone ?? '-',
                                    font, fontSizeNormal),
                              ])),
                      pw.SizedBox(width: 10),
                      // Right: Doc Info
                      pw.Expanded(
                          flex: 4,
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _buildLabelValue(
                                    'เลขที่',
                                    orderId.toString().padLeft(8, '0'),
                                    font,
                                    fontSizeNormal),
                                _buildLabelValue(
                                    'วันที่',
                                    DateFormat('dd/MM/yyyy')
                                        .format(DateTime.now()),
                                    font,
                                    fontSizeNormal),
                                _buildLabelValue(
                                    'เวลา',
                                    DateFormat('HH:mm:ss')
                                        .format(DateTime.now()),
                                    font,
                                    fontSizeNormal),
                              ]))
                    ]),
                pw.SizedBox(height: 5),
                pw.Container(height: 0.5, color: PdfColors.black),

                // Table
                pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(0.8), // Seq
                      1: const pw.FlexColumnWidth(4.2), // Item
                      2: const pw.FlexColumnWidth(1.0), // Qty
                      3: const pw.FlexColumnWidth(1.5), // Price
                      4: const pw.FlexColumnWidth(1.5), // Total
                    },
                    border:
                        pw.TableBorder.all(color: PdfColors.white, width: 0),
                    children: [
                      pw.TableRow(
                          decoration: const pw.BoxDecoration(
                              border:
                                  pw.Border(bottom: pw.BorderSide(width: 0.5))),
                          children: [
                            _cell('ลำดับ', font, fontSizeNormal,
                                align: pw.TextAlign.center),
                            _cell('รายการ', font, fontSizeNormal,
                                align: pw.TextAlign.left),
                            _cell('จำนวน', font, fontSizeNormal,
                                align: pw.TextAlign.center),
                            _cell('ราคา', font, fontSizeNormal,
                                align: pw.TextAlign.right),
                            _cell('รวม', font, fontSizeNormal,
                                align: pw.TextAlign.right),
                          ]),
                      ...items.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final item = entry.value;
                        final p = item['product'] as PosProduct;
                        final qty = item['qty'] as int;
                        final price = item['price'] as double;
                        final total = price * qty;
                        return pw.TableRow(children: [
                          _cell('$index', font, fontSizeNormal,
                              align: pw.TextAlign.center),
                          _cell(p.name, font, fontSizeNormal,
                              align: pw.TextAlign.left),
                          _cell('$qty', font, fontSizeNormal,
                              align: pw.TextAlign.center),
                          _cell(_formatMoney(price), font, fontSizeNormal,
                              align: pw.TextAlign.right),
                          _cell(_formatMoney(total), font, fontSizeNormal,
                              align: pw.TextAlign.right),
                        ]);
                      }),
                    ]),
                pw.Container(height: 0.5, color: PdfColors.black),
              ]),

              // Bottom Section
              pw.Column(children: [
                pw.SizedBox(height: 5),
                pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Notes area
                      pw.Expanded(
                          flex: 6,
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('หมายเหตุ:',
                                    style: pw.TextStyle(
                                        font: font, fontSize: fontSizeNormal)),
                                pw.Container(
                                    height: 20,
                                    decoration: const pw.BoxDecoration(
                                        border: pw.Border(
                                            bottom: pw.BorderSide(
                                                style: pw.BorderStyle.dotted,
                                                width: 0.5))))
                              ])),
                      pw.SizedBox(width: 10),
                      // Summary
                      pw.Expanded(
                          flex: 4,
                          child: pw.Column(children: [
                            _summaryRow(
                                'ยอดรวมทั้งสิ้น :',
                                _formatMoney(totalAmount),
                                fontBold,
                                fontSizeNormal),
                          ]))
                    ]),
                pw.SizedBox(height: 20),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildSignature('ผู้ส่งของ', font, fontSizeNormal),
                      _buildSignature('ผู้รับของ', font, fontSizeNormal),
                    ])
              ])
            ],
          );
        }));

    return pdf.save();
  }

  // --- Internal Widgets ---

  static pw.Widget _cell(String text, pw.Font font, double size,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: size),
            textAlign: align,
            maxLines: 1,
            overflow: pw.TextOverflow.clip));
  }

  static pw.Widget _buildTotalRow(
      String label, String value, pw.Font font, double size) {
    return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: size)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: size)),
        ]);
  }

  static pw.Widget _summaryRow(
      String label, String value, pw.Font font, double fontSize) {
    return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(font: font, fontSize: fontSize)),
              pw.Text(value,
                  style: pw.TextStyle(font: font, fontSize: fontSize)),
            ]));
  }

  static pw.Widget _buildLabelValue(
      String label, String value, pw.Font font, double fontSize) {
    return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1.0),
        child:
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(
              width: 40,
              child: pw.Text('$label:',
                  style: pw.TextStyle(font: font, fontSize: fontSize))),
          pw.Expanded(
              child: pw.Text(value,
                  style: pw.TextStyle(font: font, fontSize: fontSize),
                  maxLines: 2)),
        ]));
  }

  static pw.Widget _buildSignature(
      String label, pw.Font font, double fontSize) {
    return pw.Column(children: [
      pw.Text('..........................', style: pw.TextStyle(font: font)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: pw.TextStyle(font: font, fontSize: fontSize)),
    ]);
  }
}
