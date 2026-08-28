import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/evaluation.dart';
import '../utils/formatters.dart';
import 'export_service.dart';

/// The one-page visit report, as the farmer receives it.
///
/// Deliberately light rather than the app's dark theme: this document gets
/// printed or opened in daylight, and a dark page wastes ink and reads
/// badly. The score colours carry over so the bands still mean the same
/// thing; the surface does not.
///
/// What is NOT in here matters as much as what is. The per-section internal
/// field notes never appear — they are the officer's working notes, not
/// something the farmer was ever meant to read. Only the recommendation is
/// written for them.
class PdfReport {
  PdfReport._();

  // Score ramp, as PDF colours.
  static const _ramp = <PdfColor>[
    PdfColor.fromInt(0xFFC0392B),
    PdfColor.fromInt(0xFFD35400),
    PdfColor.fromInt(0xFFC9A227),
    PdfColor.fromInt(0xFF5E9134),
    PdfColor.fromInt(0xFF2E7D32),
  ];

  static const _ink = PdfColor.fromInt(0xFF1A1A1A);
  static const _muted = PdfColor.fromInt(0xFF767676);
  static const _rule = PdfColor.fromInt(0xFFD8D8D8);
  static const _tint = PdfColor.fromInt(0xFFF4F4F2);
  static const _green = PdfColor.fromInt(0xFF2E7D32);

  static PdfColor _forSection(int score) =>
      _ramp[(score.clamp(1, 5)) - 1];

  static PdfColor _forTotal(int total) =>
      _forSection((total / 7).round().clamp(1, 5));

  /// Build and hand straight to the browser.
  static Future<void> download(Evaluation v) async {
    final bytes = await build(v);
    ExportService.saveBytes(
      bytes,
      '${_slug(v.farmName)}-${_isoDate(v.evaluationDate)}.pdf',
      'application/pdf',
    );
  }

  static Future<Uint8List> build(Evaluation v) async {
    final doc = pw.Document(
      title: '${v.farmName} — farm evaluation',
      author: "Farmer's Choice · CM Beef",
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(38, 36, 38, 32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(v),
            pw.SizedBox(height: 18),
            _facts(v),
            pw.SizedBox(height: 16),
            _scoreBlock(v),
            pw.SizedBox(height: 18),
            _sections(v),
            pw.SizedBox(height: 16),
            _notes(v),
            pw.Spacer(),
            _footer(v),
          ],
        ),
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------

  static pw.Widget _header(Evaluation v) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('FARMER\u2019S CHOICE  \u00B7  CM BEEF',
                      style: pw.TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.4,
                          color: _green,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text(v.farmName,
                      style: pw.TextStyle(
                          fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text('Farm evaluation report',
                      style:
                          const pw.TextStyle(fontSize: 11, color: _muted)),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _rule),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(Fmt.date(v.evaluationDate),
                  style: const pw.TextStyle(fontSize: 10, color: _muted)),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(height: 2, color: _green),
      ],
    );
  }

  static pw.Widget _facts(Evaluation v) {
    pw.Widget row(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 78,
                child: pw.Text(label,
                    style:
                        const pw.TextStyle(fontSize: 9.5, color: _muted)),
              ),
              pw.Expanded(
                child: pw.Text(value,
                    style: const pw.TextStyle(fontSize: 10.5)),
              ),
            ],
          ),
        );

    final location = [v.county, v.subCounty]
        .where((s) => s.isNotEmpty)
        .join(' \u00B7 ');

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _tint,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          row('Location', location.isEmpty ? '\u2014' : location),
          row('Evaluator', v.eoName),
          row(
            'Herd',
            '${Fmt.thousands(v.totalHerd)} head  '
            '(${v.breedingCows} cows, ${v.bulls} bulls, '
            '${v.calves} calves, ${v.growersSteers} growers)',
          ),
        ],
      ),
    );
  }

  static pw.Widget _scoreBlock(Evaluation v) {
    final color = _forTotal(v.totalScore);

    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _rule),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              children: [
                pw.Text('TOTAL SCORE',
                    style: pw.TextStyle(
                        fontSize: 8, letterSpacing: 1.1, color: _muted)),
                pw.SizedBox(height: 6),
                pw.Text('${v.totalScore} / 35',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 14),
            decoration: pw.BoxDecoration(
              color: PdfColor(color.red, color.green, color.blue, 0.12),
              border: pw.Border.all(
                  color: PdfColor(color.red, color.green, color.blue, 0.55)),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              children: [
                pw.Text('RATING',
                    style: pw.TextStyle(
                        fontSize: 8, letterSpacing: 1.1, color: _muted)),
                pw.SizedBox(height: 6),
                pw.Text(v.ratingLabel,
                    style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _sections(Evaluation v) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _heading('Section scores'),
        pw.SizedBox(height: 8),
        for (final key in Sections.keys)
          if (v.sections.containsKey(key))
            _sectionRow(
                Sections.label(key), v.sections[key]!.score),
      ],
    );
  }

  static pw.Widget _sectionRow(String label, int score) {
    final color = _forSection(score);

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: 168,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          ),
          // Five blocks rather than a number alone — the farmer reads the
          // shape before they read the digit.
          pw.Row(
            children: [
              for (var n = 1; n <= 5; n++)
                pw.Container(
                  width: 26,
                  height: 7,
                  margin: const pw.EdgeInsets.only(right: 3),
                  decoration: pw.BoxDecoration(
                    color: n <= score ? color : _rule,
                    borderRadius: pw.BorderRadius.circular(1.5),
                  ),
                ),
            ],
          ),
          pw.Spacer(),
          pw.Text('$score / 5',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  static pw.Widget _notes(Evaluation v) {
    final blocks = <pw.Widget>[];

    if (v.keyStrengths.isNotEmpty) {
      blocks.add(_bulletBlock(
          'What is working well', v.keyStrengths, _green));
      blocks.add(pw.SizedBox(height: 12));
    }
    if (v.areasImprovement.isNotEmpty) {
      blocks.add(_bulletBlock('Areas to improve', v.areasImprovement,
          const PdfColor.fromInt(0xFFC9A227)));
      blocks.add(pw.SizedBox(height: 12));
    }
    if (v.recommendations.isNotEmpty) {
      blocks.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(13),
          decoration: pw.BoxDecoration(
            color: _tint,
            borderRadius: pw.BorderRadius.circular(5),
            border: const pw.Border(
                left: pw.BorderSide(color: _green, width: 3)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('RECOMMENDATIONS AND ACTION PLAN',
                  style: pw.TextStyle(
                      fontSize: 8,
                      letterSpacing: 1.1,
                      color: _green,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 7),
              pw.Text(v.recommendations,
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 3.2)),
            ],
          ),
        ),
      );
    }

    if (blocks.isEmpty) return pw.SizedBox.shrink();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: blocks,
    );
  }

  static pw.Widget _bulletBlock(
      String title, List<String> items, PdfColor accent) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _heading(title),
        pw.SizedBox(height: 6),
        for (final item in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 4,
                  height: 4,
                  margin: const pw.EdgeInsets.only(top: 4, right: 8),
                  decoration: pw.BoxDecoration(
                    color: accent,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(item,
                      style: const pw.TextStyle(
                          fontSize: 10.5, lineSpacing: 2.5)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _heading(String text) => pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
            fontSize: 8.5,
            letterSpacing: 1.2,
            color: _muted,
            fontWeight: pw.FontWeight.bold),
      );

  static pw.Widget _footer(Evaluation v) {
    return pw.Column(
      children: [
        pw.Container(height: 0.6, color: _rule),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Visited ${Fmt.date(v.evaluationDate)} by ${v.eoName}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
            pw.Text(
              'Generated ${Fmt.date(DateTime.now())} \u00B7 '
              "Farmer's Choice CM Beef",
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
      ],
    );
  }

  static String _isoDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _slug(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'visit' : cleaned;
  }
}