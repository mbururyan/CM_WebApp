import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:web/web.dart' as web;

import 'export_tables.dart';

/// Encodes tables and hands them to the browser as a download.
///
/// Everything happens client-side: the rows are already in memory, so there
/// is no server round trip and no Cloud Function — which matters, because
/// the Spark plan doesn't have them.
class ExportService {
  ExportService._();

  /// Multi-sheet .xlsx.
  static void downloadWorkbook({
    required List<ExportTable> tables,
    required String filename,
  }) {
    final book = Excel.createExcel();

    for (final table in tables) {
      final sheet = book[_safeSheetName(table.name)];
      sheet.appendRow(
        table.headers.map<CellValue?>((h) => TextCellValue(h)).toList(),
      );
      for (final row in table.rows) {
        sheet.appendRow(row.map(_cell).toList());
      }
    }

    // createExcel() seeds a default sheet; leaving it produces an empty
    // first tab, which looks like a bug to whoever opens the file.
    if (book.sheets.containsKey('Sheet1') && tables.isNotEmpty) {
      book.delete('Sheet1');
    }

    // encode(), NOT save(). save() has a side effect on web: it triggers
    // its own download named FlutterExcel.xlsx, so every click produced two
    // files. encode() just returns the bytes and lets us name the download.
    final bytes = book.encode();
    if (bytes == null) {
      throw Exception('Could not build the workbook.');
    }

    _save(
      Uint8List.fromList(bytes),
      filename.endsWith('.xlsx') ? filename : '$filename.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Single-table .csv. Kept as a fallback: it has no dependencies beyond
  /// dart:convert, so if the workbook ever fails the data is still gettable.
  static void downloadCsv({
    required ExportTable table,
    required String filename,
  }) {
    final buf = StringBuffer();
    buf.writeln(table.headers.map(_csvCell).join(','));
    for (final row in table.rows) {
      buf.writeln(row.map(_csvCell).join(','));
    }

    // The BOM makes Excel read the file as UTF-8. Without it, Kenyan place
    // names with accents open as mojibake.
    final bytes = Uint8List.fromList([
      0xEF, 0xBB, 0xBF,
      ...utf8.encode(buf.toString()),
    ]);

    _save(
      bytes,
      filename.endsWith('.csv') ? filename : '$filename.csv',
      'text/csv;charset=utf-8',
    );
  }

  // ---------------------------------------------------------------

  static CellValue? _cell(Object? v) {
    if (v == null) return null;
    if (v is int) return IntCellValue(v);
    if (v is double) return DoubleCellValue(v);
    if (v is bool) return TextCellValue(v ? 'Yes' : 'No');
    return TextCellValue(v.toString());
  }

  static String _csvCell(Object? v) {
    if (v == null) return '';
    final s = v.toString();
    // Quote when the value contains a comma, quote, or newline; double any
    // embedded quotes. This is the whole of RFC 4180 that matters here.
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Excel rejects : \ / ? * [ ] in sheet names and caps them at 31 chars.
  static String _safeSheetName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[:\\/\?\*\[\]]'), '-');
    return cleaned.length <= 31 ? cleaned : cleaned.substring(0, 31);
  }

  /// Builds a blob, clicks an invisible link, revokes the object URL.
  /// The revoke matters — without it the bytes stay pinned in memory for
  /// the life of the tab, and a manager pulling ten exports would feel it.
  static void _save(Uint8List bytes, String filename, String mime) {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mime),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor =
        web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..download = filename
          ..style.display = 'none';

    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  /// `cm-beef-visits-2026-08-27.xlsx`
  static String stamped(String prefix, {DateTime? now}) {
    final d = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '$prefix-${d.year}-${two(d.month)}-${two(d.day)}';
  }
}