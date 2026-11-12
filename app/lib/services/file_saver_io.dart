import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

Future<String?> saveSpreadsheet(BuildContext context, Uint8List bytes, String fileName) async {
  if (Platform.isAndroid) {
    // Public Downloads folder (apps may create files there on Android 11+);
    // fall back to the app's own documents folder.
    File file;
    String where;
    try {
      file = File('/storage/emulated/0/Download/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      where = 'Saved to Downloads';
    } catch (_) {
      final dir = await getApplicationDocumentsDirectory();
      file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      where = 'Saved in the app folder';
    }
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: _mime)], subject: fileName));
    return where;
  }
  final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: _mime, dialogTitle: 'Save Excel file');
  if (uri == null) return null;
  return 'Saved $fileName';
}
