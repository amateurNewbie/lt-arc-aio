/// Lưu bytes ra tệp — Web dùng Blob + thẻ `<a download>`, desktop/mobile dùng
/// hộp thoại lưu tệp gốc (file_picker). Không có API chung cho cả 2 nên phải
/// conditional-export theo nền tảng biên dịch.
library;

export 'file_downloader_stub.dart' if (dart.library.html) 'file_downloader_web.dart' if (dart.library.io) 'file_downloader_io.dart';
