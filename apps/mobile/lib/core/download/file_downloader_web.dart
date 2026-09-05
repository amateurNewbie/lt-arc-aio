// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// Chỉ dùng qua conditional export (`file_downloader.dart`) khi biên dịch cho
// Web — `dart:html` vẫn là cách chuẩn duy nhất để kích hoạt tải tệp qua thẻ
// `<a download>` ở thời điểm viết (Flutter 3.47 / Dart 3.13).
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveBytesToFile({required String fileName, required List<int> bytes}) async {
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
