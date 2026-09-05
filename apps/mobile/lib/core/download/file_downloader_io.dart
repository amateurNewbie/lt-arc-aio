import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> saveBytesToFile({required String fileName, required List<int> bytes}) async {
  await FilePicker.platform.saveFile(fileName: fileName, bytes: Uint8List.fromList(bytes));
}
