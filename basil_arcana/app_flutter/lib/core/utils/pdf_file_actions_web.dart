import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

String _createPdfObjectUrl(Uint8List bytes) {
  final blob = html.Blob(<Object>[bytes], 'application/pdf');
  return html.Url.createObjectUrlFromBlob(blob);
}

void _scheduleRevoke(String url) {
  unawaited(
    Future<void>.delayed(const Duration(minutes: 1), () {
      html.Url.revokeObjectUrl(url);
    }),
  );
}

void _triggerDownload({
  required String url,
  required String fileName,
}) {
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
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

Future<void> exportPdfFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  final shared = await _trySystemShare(bytes: bytes, fileName: fileName);
  if (shared) {
    return;
  }
  final url = _createPdfObjectUrl(bytes);
  _scheduleRevoke(url);
  _triggerDownload(url: url, fileName: fileName);
}

Future<bool> _trySystemShare({
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    final dynamic nav = html.window.navigator;
    final dynamic shareFn = nav.share;
    if (shareFn == null) {
      return false;
    }
    final file = html.File([bytes], fileName, {'type': 'application/pdf'});
    final payload = <String, Object>{
      'title': fileName,
      'files': [file],
    };
    final dynamic canShareFn = nav.canShare;
    if (canShareFn != null) {
      final canShare = canShareFn(payload);
      if (canShare != true) {
        return false;
      }
    }
    await shareFn(payload);
    return true;
  } catch (_) {
    return false;
  }
}
