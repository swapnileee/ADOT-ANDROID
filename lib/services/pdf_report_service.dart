import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';

class PdfReportService {
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

/// Printable Report View Widget mounted in Render Tree for crisp native text rasterization
class PdfReportViewWidget extends StatelessWidget {
  final String title;
  final String dateRange;
  final String currentDate;
  final double totalSales;
  final double totalExpenses;
  final double netProfit;
  final double totalDue;
  final List<Map<String, dynamic>> salesList;

  const PdfReportViewWidget({
    super.key,
    required this.title,
    required this.dateRange,
    required this.currentDate,
    required this.totalSales,
    required this.totalExpenses,
    required this.netProfit,
    required this.totalDue,
    required this.salesList,
  });

  @override
  Widget build(BuildContext context) {
    final banglaStyle = GoogleFonts.notoSansBengali(
      textStyle: const TextStyle(color: AppTheme.textDark),
    );

    return Container(
      width: 794,
      height: 1123,
      padding: const EdgeInsets.all(36),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title | আদত স্টোর',
                      style: GoogleFonts.notoSansBengali(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'সেলস ও হিসাব স্টেটমেন্ট রিপোর্ট (সময়কাল: $dateRange)',
                      style: GoogleFonts.notoSansBengali(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentGold,
                      ),
                    ),
                  ],
                ),
                Text(
                  currentDate,
                  style: GoogleFonts.notoSansBengali(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Financial Summary Title
          Text(
            'আর্থিক হিসাবের সারসংক্ষেপ (সময়কাল: $dateRange)',
            style: GoogleFonts.notoSansBengali(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 10),

          // Summary Table
          Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 1),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('খাত / শিরোনাম', style: banglaStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('টাকার পরিমাণ (৳)', style: banglaStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right),
                  ),
                ],
              ),
              _buildTableRow('সর্বমোট বিক্রি (Total Sales)', '৳ ${totalSales.toStringAsFixed(0)}', banglaStyle),
              _buildTableRow('সর্বমোট খরচ (Total Expenses)', '৳ ${totalExpenses.toStringAsFixed(0)}', banglaStyle),
              _buildTableRow(
                'নিট লাভ / ব্যালেন্স (Net Profit)',
                '৳ ${netProfit.toStringAsFixed(0)}',
                banglaStyle,
                isBold: true,
                bgColor: const Color(0xFFE6F4EA),
              ),
              _buildTableRow('মোট বাকি/বকেয়া (Total Due)', '৳ ${totalDue.toStringAsFixed(0)}', banglaStyle),
            ],
          ),

          const SizedBox(height: 24),

          // Sales Details Title
          Text(
            'বিক্রয়ের বিবরণ (সর্বশেষ ${salesList.length}টি)',
            style: GoogleFonts.notoSansBengali(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 10),

          // Sales Details Table
          Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 1),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: AppTheme.primaryGreen),
                children: [
                  Padding(padding: const EdgeInsets.all(8), child: Text('পণ্যের নাম', style: banglaStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: const EdgeInsets.all(8), child: Text('পরিমাণ', style: banglaStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: const EdgeInsets.all(8), child: Text('ক্রেতা', style: banglaStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: const EdgeInsets.all(8), child: Text('মূল্য (৳)', style: banglaStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                  Padding(padding: const EdgeInsets.all(8), child: Text('বকেয়া (৳)', style: banglaStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                ],
              ),
              ...salesList.map((sale) {
                return TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text(sale['product_name'] ?? '', style: banglaStyle.copyWith(fontSize: 10))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(sale['quantity'] ?? '', style: banglaStyle.copyWith(fontSize: 10))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(sale['customer_name'] ?? 'নগদ', style: banglaStyle.copyWith(fontSize: 10))),
                    Padding(padding: const EdgeInsets.all(8), child: Text('৳ ${sale['total_price'] ?? '0'}', style: banglaStyle.copyWith(fontSize: 10), textAlign: TextAlign.right)),
                    Padding(padding: const EdgeInsets.all(8), child: Text('৳ ${sale['due_amount'] ?? '0'}', style: banglaStyle.copyWith(fontSize: 10), textAlign: TextAlign.right)),
                  ],
                );
              }),
            ],
          ),

          const Spacer(),

          // Footer
          Divider(color: Colors.grey.shade300),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ADOT Digital Khata App - v1.0.2', style: banglaStyle.copyWith(fontSize: 10, color: Colors.grey.shade600)),
              Text('স্বয়ংক্রিয়ভাবে তৈরি করা রিপোর্ট ($dateRange)', style: banglaStyle.copyWith(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String label, String value, TextStyle style, {bool isBold = false, Color? bgColor}) {
    return TableRow(
      decoration: bgColor != null ? BoxDecoration(color: bgColor) : null,
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            label,
            style: style.copyWith(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: style.copyWith(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
