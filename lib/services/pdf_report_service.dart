import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/sale_model.dart';

class PdfReportService {
  static Future<void> generateAndPreviewReport({
    required double totalSales,
    required double totalExpenses,
    required double totalDue,
    required List<SaleModel> salesList,
    String periodTitle = 'এই মাস',
  }) async {
    // Safely load Bengali font (Local Asset -> Network Google Fonts -> Standard Helvetica)
    pw.Font banglaFont;
    pw.Font banglaFontBold;
    try {
      final fontData = await rootBundle.load('assets/fonts/Kalpurush.ttf');
      banglaFont = pw.Font.ttf(fontData);
      banglaFontBold = pw.Font.ttf(fontData);
    } catch (_) {
      try {
        banglaFont = await PdfGoogleFonts.tiroBanglaRegular();
        banglaFontBold = banglaFont;
      } catch (_) {
        banglaFont = pw.Font.helvetica();
        banglaFontBold = pw.Font.helveticaBold();
      }
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: banglaFont,
        bold: banglaFontBold,
      ),
    );

    final netProfit = totalSales - totalExpenses;
    final currentDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#076040'), // AppTheme.primaryGreen
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ADOT | আদত স্টোর ক্যাশিয়ার',
                          style: pw.TextStyle(
                            font: banglaFontBold,
                            color: PdfColors.white,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'সেলস ও হিসাব স্টেটমেন্ট রিপোর্ট (সময়কাল: $periodTitle)',
                          style: pw.TextStyle(
                            font: banglaFont,
                            color: PdfColor.fromHex('#E0C38C'), // AppTheme.accentGold
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      currentDate,
                      style: pw.TextStyle(
                        font: banglaFont,
                        color: PdfColors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Summary Stats Section
              pw.Text(
                'আর্থিক হিসাবের সারসংক্ষেপ (সময়কাল: $periodTitle)',
                style: pw.TextStyle(
                  font: banglaFontBold,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('খাত / শিরোনাম', style: pw.TextStyle(font: banglaFontBold, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('টাকার পরিমাণ (৳)', style: pw.TextStyle(font: banglaFontBold, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  _buildTableRow('সর্বমোট বিক্রি (Total Sales)', '৳ ${totalSales.toStringAsFixed(0)}', banglaFont, boldFont: banglaFontBold),
                  _buildTableRow('সর্বমোট খরচ (Total Expenses)', '৳ ${totalExpenses.toStringAsFixed(0)}', banglaFont, boldFont: banglaFontBold),
                  _buildTableRow(
                    'নিট লাভ / ব্যালেন্স (Net Profit)',
                    '৳ ${netProfit.toStringAsFixed(0)}',
                    banglaFont,
                    boldFont: banglaFontBold,
                    isBold: true,
                  ),
                  _buildTableRow('মোট বাকি/বকেয়া (Total Due)', '৳ ${totalDue.toStringAsFixed(0)}', banglaFont, boldFont: banglaFontBold),
                ],
              ),

              pw.SizedBox(height: 24),

              // Recent Sales Table
              pw.Text(
                'বিক্রয়ের বিবরণ (সর্বশেষ ${salesList.take(15).length}টি)',
                style: pw.TextStyle(
                  font: banglaFontBold,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E6F4EA')),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('পণ্যের নাম', style: pw.TextStyle(font: banglaFontBold, fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('পরিমাণ', style: pw.TextStyle(font: banglaFontBold, fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('ক্রেতা', style: pw.TextStyle(font: banglaFontBold, fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('মূল্য (৳)', style: pw.TextStyle(font: banglaFontBold, fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('বকেয়া (৳)', style: pw.TextStyle(font: banglaFontBold, fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ],
                  ),
                  ...salesList.take(15).map((sale) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(sale.productName, style: pw.TextStyle(font: banglaFont, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${sale.quantity}টি', style: pw.TextStyle(font: banglaFont, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(sale.customerName.isEmpty ? 'নগদ' : sale.customerName, style: pw.TextStyle(font: banglaFont, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('৳ ${sale.totalPrice.toStringAsFixed(0)}', style: pw.TextStyle(font: banglaFont, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('৳ ${sale.dueAmount.toStringAsFixed(0)}', style: pw.TextStyle(font: banglaFont, fontSize: 9))),
                      ],
                    );
                  }),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ADOT Digital Khata App - v1.0.2', style: pw.TextStyle(font: banglaFont, fontSize: 9, color: PdfColors.grey600)),
                  pw.Text('স্বয়ংক্রিয়ভাবে তৈরি করা রিপোর্ট ($periodTitle)', style: pw.TextStyle(font: banglaFont, fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Open Native Print / Save / Preview Dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'ADOT_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.TableRow _buildTableRow(String label, String value, pw.Font font, {bool isBold = false, pw.Font? boldFont}) {
    final usedFont = isBold ? (boldFont ?? font) : font;
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: usedFont,
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: usedFont,
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
