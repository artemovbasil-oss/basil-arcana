import 'dart:typed_data';

import 'package:printing/printing.dart';

Future<void> exportPdfFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  await Printing.sharePdf(
    bytes: bytes,
    filename: fileName,
  );
}

Future<void> openPdfFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  await exportPdfFile(bytes: bytes, fileName: fileName);
}

Future<void> sharePdfFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  await exportPdfFile(bytes: bytes, fileName: fileName);
}
