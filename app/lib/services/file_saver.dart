import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'file_saver_stub.dart' if (dart.library.io) 'file_saver_io.dart' as impl;

const xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Windows: "Save as" dialog. Android: saves to Downloads, then opens the
/// share sheet (WhatsApp, Drive, email...). Web (demo): browser download.
/// Returns a short description of where the file went, or null if cancelled.
Future<String?> saveSpreadsheet(BuildContext context, Uint8List bytes, String fileName) =>
    impl.saveSpreadsheet(context, bytes, fileName);
