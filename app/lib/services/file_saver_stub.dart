import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

Future<String?> saveSpreadsheet(BuildContext context, Uint8List bytes, String fileName) async {
  final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  return uri == null ? null : 'Downloaded $fileName';
}
