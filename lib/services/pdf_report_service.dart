import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfReportService {
  // Memory cache for text-to-image conversion during PDF generation
  static final Map<String, pw.MemoryImage> _textImageCache = {};

  /// Renders any Bengali/mixed text string via Flutter's native TextPainter + Canvas into a crisp pw.MemoryImage
  static Future<pw.MemoryImage> _getTextImage({
    required String text,
    double fontSize = 12.0,
    Color color = Colors.black,
    FontWeight fontWeight = FontWeight.normal,
    TextAlign textAlign = TextAlign.left,
  }) async {
    final String cleanText = text.trim().isEmpty ? ' ' : text;
    final String cacheKey = '$cleanText-${fontSize.toInt()}-${color.toARGB32()}-${fontWeight.value}-${textAlign.name}';

    if (_textImageCache.containsKey(cacheKey)) {
      return _textImageCache[cacheKey]!;
    }

    const double scale = 3.0; // 3x scale factor for high-DPI print sharpness
    final double scaledFontSize = fontSize * scale;

    final textStyle = GoogleFonts.notoSansBengali(
      fontSize: scaledFontSize,
      fontWeight: fontWeight,
      color: color,
    );

    final textSpan = TextSpan(text: cleanText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
      textAlign: textAlign,
    );

    textPainter.layout();

    final int width = (textPainter.width + 12).ceil();
    final int height = (textPainter.height + 6).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    textPainter.paint(canvas, const Offset(6, 3));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final pwImage = pw.MemoryImage(pngBytes);
    _textImageCache[cacheKey] = pwImage;
    return pwImage;
  }

  /// Generates a paginated PDF report with top summary tables and detailed sales list underneath
  static Future<void> generateAndExportReportPdf({
    required String title,
    required String dateRange,
    required String currentDate,
    required double totalSales,
    required double totalExpenses,
    required double netProfit,
    required double totalDue,
    double totalCashCollected = 0.0,
    double oldDueCollected = 0.0,
    double newDueGenerated = 0.0,
    int salesCount = 0,
    Map<String, double> expensesByCategory = const {},
    required List<Map<String, dynamic>> salesList,
  }) async {
    _textImageCache.clear();

    // 1. Pre-render Header Images
    final titleImg = await _getTextImage(text: '$title | আদত স্টোর', fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold);
    final subImg = await _getTextImage(text: 'সেলস ও হিসাব স্টেটমেন্ট রিপোর্ট (সময়কাল: $dateRange)', fontSize: 11, color: const Color(0xFFD4AF37), fontWeight: FontWeight.w600);
    final dateImg = await _getTextImage(text: currentDate, fontSize: 10, color: Colors.white);

    // 2. Pre-render Table 1: Financial Summary Section Images
    final summaryTitleImg = await _getTextImage(text: 'আর্থিক হিসাবের সারসংক্ষেপ (সময়কাল: $dateRange)', fontSize: 13, color: const Color(0xFF1E4632), fontWeight: FontWeight.bold);
    final sumHeader1Img = await _getTextImage(text: 'খাত / শিরোনাম', fontSize: 11, color: const Color(0xFF1F2937), fontWeight: FontWeight.bold);
    final sumHeader2Img = await _getTextImage(text: 'টাকার পরিমাণ (৳)', fontSize: 11, color: const Color(0xFF1F2937), fontWeight: FontWeight.bold, textAlign: TextAlign.right);

    final salesLabelImg = await _getTextImage(text: 'সর্বমোট বিক্রি (Total Sales Turnover)', fontSize: 11);
    final salesValImg = await _getTextImage(text: '৳ ${totalSales.toStringAsFixed(0)}', fontSize: 11, textAlign: TextAlign.right);

    final cashCollectedLabelImg = await _getTextImage(text: 'মোট ক্যাশ আদায় (Total Cash Collected)', fontSize: 11, fontWeight: FontWeight.bold);
    final cashCollectedValImg = await _getTextImage(text: '৳ ${totalCashCollected.toStringAsFixed(0)}', fontSize: 11, fontWeight: FontWeight.bold, textAlign: TextAlign.right);

    final expensesLabelImg = await _getTextImage(text: 'সর্বমোট খরচ (Total Expenses)', fontSize: 11);
    final expensesValImg = await _getTextImage(text: '৳ ${totalExpenses.toStringAsFixed(0)}', fontSize: 11, textAlign: TextAlign.right);

    final netProfitLabelImg = await _getTextImage(text: 'নিট লাভ (Net Profit)', fontSize: 11, fontWeight: FontWeight.bold);
    final netProfitValImg = await _getTextImage(text: '৳ ${netProfit.toStringAsFixed(0)}', fontSize: 11, fontWeight: FontWeight.bold, textAlign: TextAlign.right);

    final dueLabelImg = await _getTextImage(text: 'মোট বাকি/বকেয়া (Total Due)', fontSize: 11);
    final dueValImg = await _getTextImage(text: '৳ ${totalDue.toStringAsFixed(0)}', fontSize: 11, textAlign: TextAlign.right);

    // 3. Pre-render Table 2: Transaction & Due Breakdown Section Images
    final txnTitleImg = await _getTextImage(text: 'লেনদেন ও বকেয়ার সারসংক্ষেপ', fontSize: 13, color: const Color(0xFF1E4632), fontWeight: FontWeight.bold);
    final txnHeader1Img = await _getTextImage(text: 'বিবরণ / সূচক', fontSize: 11, color: const Color(0xFF1F2937), fontWeight: FontWeight.bold);
    final txnHeader2Img = await _getTextImage(text: 'পরিমাণ / গণনা', fontSize: 11, color: const Color(0xFF1F2937), fontWeight: FontWeight.bold, textAlign: TextAlign.right);

    final salesCountLabelImg = await _getTextImage(text: 'মোট লেনদেন (Sales Count)', fontSize: 11);
    final salesCountValImg = await _getTextImage(text: '$salesCount টি', fontSize: 11, textAlign: TextAlign.right);

    final oldDueCollectedLabelImg = await _getTextImage(text: 'আগের বাকি থেকে আদায় (Old Due Collected)', fontSize: 11);
    final oldDueCollectedValImg = await _getTextImage(text: '৳ ${oldDueCollected.toStringAsFixed(0)}', fontSize: 11, textAlign: TextAlign.right);

    final newDueGeneratedLabelImg = await _getTextImage(text: 'নতুন বাকি (New Due Generated)', fontSize: 11);
    final newDueGeneratedValImg = await _getTextImage(text: '৳ ${newDueGenerated.toStringAsFixed(0)}', fontSize: 11, textAlign: TextAlign.right);

    // 4. Pre-render Table 3: Expenses Breakdown Section Images
    final expBreakdownTitleImg = await _getTextImage(text: 'খাতওয়ারি খরচের হিসাব (Expenses Breakdown)', fontSize: 13, color: const Color(0xFF1E4632), fontWeight: FontWeight.bold);
    final expHeader1Img = await _getTextImage(text: 'খরচের খাত / টাইপ', fontSize: 11, color: const Color(0xFF1F2937), fontWeight: FontWeight.bold);
    final expHeader2Img = await _getTextImage(text: 'টাকার পরিমাণ (৳)', fontSize: 11, color: const Color(0xFF1F2937), fontWeight: FontWeight.bold, textAlign: TextAlign.right);

    final List<Map<String, pw.MemoryImage>> preparedExpenses = [];
    if (expensesByCategory.isEmpty) {
      final catImg = await _getTextImage(text: 'কোন খরচ রেকর্ড করা হয়নি', fontSize: 10);
      final valImg = await _getTextImage(text: '৳ 0', fontSize: 10, textAlign: TextAlign.right);
      preparedExpenses.add({'cat': catImg, 'val': valImg});
    } else {
      for (var entry in expensesByCategory.entries) {
        final catImg = await _getTextImage(text: entry.key, fontSize: 10);
        final valImg = await _getTextImage(text: '৳ ${entry.value.toStringAsFixed(0)}', fontSize: 10, textAlign: TextAlign.right);
        preparedExpenses.add({'cat': catImg, 'val': valImg});
      }
    }

    final expTotalLabelImg = await _getTextImage(text: 'সর্বমোট খরচ (Total Expenses)', fontSize: 11, fontWeight: FontWeight.bold);
    final expTotalValImg = await _getTextImage(text: '৳ ${totalExpenses.toStringAsFixed(0)}', fontSize: 11, fontWeight: FontWeight.bold, textAlign: TextAlign.right);

    // 5. Pre-render Section 4: Customer Sales Details Section Images (At the BOTTOM)
    final salesTitleImg = await _getTextImage(text: 'বিক্রয়ের বিবরণ (মোট ${salesList.length}টি)', fontSize: 13, color: const Color(0xFF1E4632), fontWeight: FontWeight.bold);
    final tblHeaderPNameImg = await _getTextImage(text: 'পণ্যের নাম', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold);
    final tblHeaderQtyImg = await _getTextImage(text: 'পরিমাণ', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold);
    final tblHeaderCustomerImg = await _getTextImage(text: 'ক্রেতা', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold);
    final tblHeaderPriceImg = await _getTextImage(text: 'মূল্য (৳)', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold, textAlign: TextAlign.right);
    final tblHeaderDueImg = await _getTextImage(text: 'বকেয়া (৳)', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold, textAlign: TextAlign.right);

    // 6. Pre-render Sales List Items
    final List<Map<String, pw.MemoryImage>> preparedSales = [];
    for (var sale in salesList) {
      final pName = await _getTextImage(text: sale['product_name'] ?? '', fontSize: 10);
      final qty = await _getTextImage(text: sale['quantity'] ?? '', fontSize: 10);
      final cName = await _getTextImage(text: sale['customer_name'] ?? 'নগদ', fontSize: 10);
      final price = await _getTextImage(text: '৳ ${sale['total_price'] ?? "0"}', fontSize: 10, textAlign: TextAlign.right);
      final due = await _getTextImage(text: '৳ ${sale['due_amount'] ?? "0"}', fontSize: 10, textAlign: TextAlign.right);

      preparedSales.add({
        'pName': pName,
        'qty': qty,
        'cName': cName,
        'price': price,
        'due': due,
      });
    }

    // 7. Pre-render Footer Label Image
    final footerBrandImg = await _getTextImage(text: 'ADOT Digital Khata App - v1.0.2', fontSize: 9, color: Colors.grey.shade600);
    final pagePrefixImg = await _getTextImage(text: 'পৃষ্ঠা ', fontSize: 9, color: Colors.grey.shade600);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(footerBrandImg, height: 9),
                  pw.Row(
                    children: [
                      pw.Image(pagePrefixImg, height: 9),
                      pw.Text(
                        '${context.pageNumber} / ${context.pagesCount}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // 1. Header Banner Container
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1E4632'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Image(titleImg, height: 18),
                      pw.SizedBox(height: 4),
                      pw.Image(subImg, height: 11),
                    ],
                  ),
                  pw.Image(dateImg, height: 10),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // 2. Table 1: Financial Summary Table (At the VERY TOP)
            pw.Image(summaryTitleImg, height: 13),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Image(sumHeader1Img, height: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Image(sumHeader2Img, height: 11)),
                    ),
                  ],
                ),
                _buildImageSummaryRow(salesLabelImg, salesValImg),
                _buildImageSummaryRow(cashCollectedLabelImg, cashCollectedValImg),
                _buildImageSummaryRow(expensesLabelImg, expensesValImg),
                _buildImageSummaryRow(netProfitLabelImg, netProfitValImg, bgColor: PdfColor.fromHex('#E6F4EA')),
                _buildImageSummaryRow(dueLabelImg, dueValImg),
              ],
            ),

            pw.SizedBox(height: 16),

            // 3. Table 2: Transaction & Due Breakdown Table
            pw.Image(txnTitleImg, height: 13),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Image(txnHeader1Img, height: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Image(txnHeader2Img, height: 11)),
                    ),
                  ],
                ),
                _buildImageSummaryRow(salesCountLabelImg, salesCountValImg),
                _buildImageSummaryRow(oldDueCollectedLabelImg, oldDueCollectedValImg),
                _buildImageSummaryRow(newDueGeneratedLabelImg, newDueGeneratedValImg),
              ],
            ),

            pw.SizedBox(height: 16),

            // 4. Table 3: Expenses Breakdown Table
            pw.Image(expBreakdownTitleImg, height: 13),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Image(expHeader1Img, height: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Image(expHeader2Img, height: 11)),
                    ),
                  ],
                ),
                ...preparedExpenses.map((exp) {
                  return _buildImageSummaryRow(exp['cat']!, exp['val']!);
                }),
                _buildImageSummaryRow(expTotalLabelImg, expTotalValImg, bgColor: PdfColor.fromHex('#FCE8E6')),
              ],
            ),

            pw.SizedBox(height: 16),

            // 5. Customer Sales Details Section (At the BOTTOM)
            pw.Image(salesTitleImg, height: 13),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E4632')),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Image(tblHeaderPNameImg, height: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Image(tblHeaderQtyImg, height: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Image(tblHeaderCustomerImg, height: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Image(tblHeaderPriceImg, height: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Image(tblHeaderDueImg, height: 11))),
                  ],
                ),
                ...preparedSales.map((item) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Image(item['pName']!, height: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Image(item['qty']!, height: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Image(item['cName']!, height: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Image(item['price']!, height: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Image(item['due']!, height: 10))),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'ADOT_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.TableRow _buildImageSummaryRow(pw.MemoryImage labelImg, pw.MemoryImage valueImg, {PdfColor? bgColor}) {
    return pw.TableRow(
      decoration: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Image(labelImg, height: 11)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Image(valueImg, height: 11)),
        ),
      ],
    );
  }

  /// Safely captures a RepaintBoundary widget to PNG byte array with endOfFrame validation
  static Future<Uint8List?> captureReportSafely(GlobalKey key) async {
    final BuildContext? context = key.currentContext;
    if (context == null) {
      debugPrint("Error: Report key context is null");
      return null;
    }

    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject == null || renderObject is! RenderRepaintBoundary) {
      debugPrint("Error: RenderObject is null or not a RenderRepaintBoundary");
      return null;
    }

    await WidgetsBinding.instance.endOfFrame;

    final RenderRepaintBoundary boundary = renderObject;

    try {
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturing report boundary: $e");
      return null;
    }
  }

  /// Generates a PDF document containing the captured high-definition report image
  static Future<void> exportReportAsPdf(Uint8List imageBytes) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(image, fit: pw.BoxFit.contain),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'ADOT_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
