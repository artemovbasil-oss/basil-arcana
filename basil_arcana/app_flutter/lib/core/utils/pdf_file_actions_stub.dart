import 'dart:typed_data';

import 'package:printing/printing.dart';

Future<void> openPdfFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: fileName,
  );
}

Future<void> sharePdfFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  await Printing.sharePdf(
    bytes: bytes,
    filename: fileName,
  );
}
