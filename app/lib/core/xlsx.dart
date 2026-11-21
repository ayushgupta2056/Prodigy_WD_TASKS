import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A small, dependency-light .xlsx writer.
///
/// Why not only the `excel` package: it cannot freeze panes or add an
/// autofilter, both of which the export needs. This writer produces standard
/// Office Open XML that Excel, Google Sheets, LibreOffice and the `excel`
/// package all read (the tests open the output with `excel`).
enum XStyle {
  normal, // 0
  header, // 1
  money, // 2  ₹ with Indian grouping
  date, // 3  DD-MMM-YYYY
  percent, // 4  value is a fraction: 0.153 -> 15.3%
  integer, // 5
  totalLabel, // 6
  totalMoney, // 7
  totalInteger, // 8
  decimal, // 9  0.0
  totalPercent, // 10
  title, // 11
  muted, // 12
}

class XCell {
  final Object? value; // String, num, DateTime or null
  final XStyle style;
  final String? formula; // without the leading '='
  const XCell(this.value, [this.style = XStyle.normal, this.formula]);
}

class XSheet {
  final String name;
  final List<double> columnWidths;
  final List<List<XCell>> rows = [];

  /// Freeze rows above this 1-based row and add an autofilter over
  /// [headerRow .. filterLastRow]. 0 = none.
  int headerRow;
  int filterLastRow;

  XSheet(this.name, {this.columnWidths = const [], this.headerRow = 0, this.filterLastRow = 0});

  void add(List<XCell> row) => rows.add(row);
  int get rowCount => rows.length;
  int get columnCount => rows.fold(0, (m, r) => r.length > m ? r.length : m);
}

String colName(int index) {
  var n = index + 1;
  var s = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

String cellRef(int col, int row1) => '${colName(col)}$row1';

double excelSerial(DateTime d) {
  final base = DateTime.utc(1899, 12, 30);
  return DateTime.utc(d.year, d.month, d.day).difference(base).inDays.toDouble();
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

const _moneyFmt = r'[>=10000000]"₹"##\,##\,##\,##0;[>=100000]"₹"##\,##\,##0;"₹"##,##0';

Uint8List buildXlsx(List<XSheet> sheets) {
  final strings = <String>[];
  final stringIndex = <String, int>{};
  int sst(String s) => stringIndex.putIfAbsent(s, () {
        strings.add(s);
        return strings.length - 1;
      });

  final archive = Archive();
  void addFile(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  final sheetXml = <String>[];
  for (final sh in sheets) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
    b.write('<sheetViews><sheetView workbookViewId="0"${sheets.first == sh ? ' tabSelected="1"' : ''}>');
    if (sh.headerRow > 0) {
      b.write('<pane ySplit="${sh.headerRow}" topLeftCell="A${sh.headerRow + 1}" activePane="bottomLeft" state="frozen"/>');
    }
    b.write('</sheetView></sheetViews><sheetFormatPr defaultRowHeight="16"/>');
    if (sh.columnWidths.isNotEmpty) {
      b.write('<cols>');
      for (var i = 0; i < sh.columnWidths.length; i++) {
        b.write('<col min="${i + 1}" max="${i + 1}" width="${sh.columnWidths[i]}" customWidth="1"/>');
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    for (var r = 0; r < sh.rows.length; r++) {
      final row = sh.rows[r];
      final ht = row.any((c) => c.style == XStyle.title) ? ' ht="24" customHeight="1"' : (row.any((c) => c.style == XStyle.header) ? ' ht="20" customHeight="1"' : '');
      b.write('<row r="${r + 1}"$ht>');
      for (var c = 0; c < row.length; c++) {
        final cell = row[c];
        final ref = cellRef(c, r + 1);
        final s = cell.style.index;
        final v = cell.value;
        if (cell.formula != null) {
          b.write('<c r="$ref" s="$s"><f>${_esc(cell.formula!)}</f>${v is num ? '<v>$v</v>' : ''}</c>');
        } else if (v == null) {
          if (s != 0) b.write('<c r="$ref" s="$s"/>');
        } else if (v is num) {
          b.write('<c r="$ref" s="$s"><v>${v.isFinite ? v : 0}</v></c>');
        } else if (v is DateTime) {
          b.write('<c r="$ref" s="$s"><v>${excelSerial(v).toInt()}</v></c>');
        } else {
          b.write('<c r="$ref" s="$s" t="s"><v>${sst(v.toString())}</v></c>');
        }
      }
      b.write('</row>');
    }
    b.write('</sheetData>');
    if (sh.headerRow > 0 && sh.filterLastRow >= sh.headerRow && sh.columnCount > 0) {
      b.write('<autoFilter ref="A${sh.headerRow}:${colName(sh.columnCount - 1)}${sh.filterLastRow}"/>');
    }
    b.write('<pageMargins left="0.5" right="0.5" top="0.75" bottom="0.75" header="0.3" footer="0.3"/></worksheet>');
    sheetXml.add(b.toString());
  }

  addFile('[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '${List.generate(sheets.length, (i) => '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join()}'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
      '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
      '</Types>');

  addFile('_rels/.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
      '</Relationships>');

  addFile('docProps/core.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>Booking Manager export</dc:title>'
      '<dc:creator>Booking Manager</dc:creator></cp:coreProperties>');
  addFile('docProps/app.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>Booking Manager</Application></Properties>');

  final defined = <String>[];
  for (var i = 0; i < sheets.length; i++) {
    final sh = sheets[i];
    if (sh.headerRow > 0 && sh.filterLastRow >= sh.headerRow && sh.columnCount > 0) {
      defined.add('<definedName name="_xlnm._FilterDatabase" localSheetId="$i" hidden="1">'
          '${_esc("'${sh.name.replaceAll("'", "''")}'")}!\$A\$${sh.headerRow}:\$${colName(sh.columnCount - 1)}\$${sh.filterLastRow}</definedName>');
    }
  }
  addFile('xl/workbook.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<bookViews><workbookView/></bookViews><sheets>'
      '${List.generate(sheets.length, (i) => '<sheet name="${_esc(sheets[i].name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>').join()}'
      '</sheets>${defined.isEmpty ? '' : '<definedNames>${defined.join()}</definedNames>'}'
      '<calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>');

  addFile('xl/_rels/workbook.xml.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${List.generate(sheets.length, (i) => '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>').join()}'
      '<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '<Relationship Id="rId${sheets.length + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>'
      '</Relationships>');

  // cellXfs order must match XStyle.
  String xf(int numFmt, int font, int fill, int border, {String align = ''}) =>
      '<xf numFmtId="$numFmt" fontId="$font" fillId="$fill" borderId="$border" xfId="0"'
      '${numFmt != 0 ? ' applyNumberFormat="1"' : ''}${font != 0 ? ' applyFont="1"' : ''}'
      '${fill != 0 ? ' applyFill="1"' : ''}${border != 0 ? ' applyBorder="1"' : ''}'
      '${align.isNotEmpty ? ' applyAlignment="1"><alignment $align/></xf>' : '/>'}';
  final xfs = [
    xf(0, 0, 0, 0), // normal
    xf(0, 1, 2, 1, align: 'vertical="center"'), // header
    xf(164, 0, 0, 0), // money
    xf(165, 0, 0, 0, align: 'horizontal="left"'), // date
    xf(166, 0, 0, 0), // percent
    xf(1, 0, 0, 0), // integer
    xf(0, 1, 0, 2), // total label
    xf(164, 1, 0, 2), // total money
    xf(1, 1, 0, 2), // total integer
    xf(167, 0, 0, 0), // decimal
    xf(166, 1, 0, 2), // total percent
    xf(0, 3, 0, 0), // title
    xf(0, 4, 0, 0), // muted
  ];
  addFile('xl/styles.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="4">'
      '<numFmt numFmtId="164" formatCode="${_esc(_moneyFmt)}"/>'
      '<numFmt numFmtId="165" formatCode="dd\\-mmm\\-yyyy"/>'
      '<numFmt numFmtId="166" formatCode="0.0%"/>'
      '<numFmt numFmtId="167" formatCode="0.0"/>'
      '</numFmts>'
      '<fonts count="5">'
      '<font><sz val="11"/><name val="Calibri"/><family val="2"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/><family val="2"/></font>'
      '<font><sz val="11"/><name val="Calibri"/><family val="2"/></font>'
      '<font><b/><sz val="15"/><color rgb="FF1F4D3F"/><name val="Calibri"/><family val="2"/></font>'
      '<font><sz val="10"/><color rgb="FF7A7468"/><name val="Calibri"/><family val="2"/></font>'
      '</fonts>'
      '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFF1ECE2"/><bgColor indexed="64"/></patternFill></fill></fills>'
      '<borders count="3"><border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left/><right/><top/><bottom style="thin"><color rgb="FFC9C1B2"/></bottom><diagonal/></border>'
      '<border><left/><right/><top style="thin"><color rgb="FF1F4D3F"/></top><bottom style="double"><color rgb="FF1F4D3F"/></bottom><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="${xfs.length}">${xfs.join()}</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>');

  for (var i = 0; i < sheetXml.length; i++) {
    addFile('xl/worksheets/sheet${i + 1}.xml', sheetXml[i]);
  }

  addFile('xl/sharedStrings.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${strings.length}" uniqueCount="${strings.length}">'
      '${strings.map((s) => '<si><t xml:space="preserve">${_esc(s)}</t></si>').join()}</sst>');

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
