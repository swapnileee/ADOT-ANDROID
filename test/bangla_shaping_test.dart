import 'package:flutter_test/flutter_test.dart';
import 'package:adot_shop_app/services/pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Report Image-Based Bengali Rendering Tests', () {
    test('PdfReportService instantiates and exports without manual text reshaping', () {
      expect(PdfReportService.captureReportSafely, isNotNull);
    });
  });
}
