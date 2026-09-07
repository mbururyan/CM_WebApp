import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../constants/evaluation_template.dart';
import '../models/evaluation.dart';
import '../utils/formatters.dart';
import 'export_service.dart';

/// The visit report, as the farmer receives it.
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
///
/// Flows across as many A4 pages as the content needs. It used to be a
/// single fixed page, which was fine until the vaccination table arrived —
/// a farm with six diseases recorded cannot share one page with everything
/// above it.
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

  /// Nothing in place — off the ramp on purpose, matching the app.
  static const _zero = PdfColor.fromInt(0xFF8E3B32);

  /// 0-5. Zero is its own colour: under v2 scoring a section can genuinely
  /// score nothing, and painting that as poor-red would read as a 1 and
  /// bury the worst finding on the page.
  static PdfColor _forSection(int score) =>
      score <= 0 ? _zero : _ramp[(score.clamp(1, 5)) - 1];

  /// Colour for the rating panel, taken from the BAND rather than from
  /// arithmetic on the total.
  ///
  /// The old version computed (total / 7).round(), which can disagree with
  /// the word actually printed beside it when a score sits near a
  /// threshold — the panel would read "Good" in the colour of Fair. Bands
  /// come from ConfigService, so this cannot drift from the label.
  static PdfColor _forBand(String band) {
    switch (band) {
      case 'poor':
        return _ramp[0];
      case 'fair':
        return _ramp[2];
      case 'good':
        return _ramp[3];
      case 'excellent':
        return _ramp[4];
      default:
        return _muted;
    }
  }

  /// Mix a colour toward white by [amount] (0 = untouched, 1 = white).
  ///
  /// Used instead of an alpha channel. dart_pdf does not apply the alpha
  /// component of a PdfColor to a BoxDecoration fill, so the rating panel
  /// rendered as flat 100% green with its own green label invisible on top
  /// of it. A blended opaque colour needs no transparency support at all.
  static PdfColor _wash(PdfColor c, double amount) => PdfColor(
        c.red + (1 - c.red) * amount,
        c.green + (1 - c.green) * amount,
        c.blue + (1 - c.blue) * amount,
      );

  /// Loaded once and reused. The PDF standard fonts (Helvetica and
  /// friends) are Latin-1 only and carry no Unicode table, so dart_pdf
  /// THROWS rather than substituting the moment a character falls outside
  /// that range. A curly apostrophe is enough to kill the document, and
  /// this file contains several of its own before any farm data arrives.
  ///
  /// IBM Plex is also what the dashboard uses on screen, so the report now
  /// looks like it came from the same product.
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> _loadTheme() async {
    final held = _theme;
    if (held != null) return held;

    final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/IBMPlexSans-Regular.ttf'));
    final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/IBMPlexSans-SemiBold.ttf'));

    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    _theme = theme;
    return theme;
  }

  /// The light-document lockup, with the skull in ink rather than white.
  /// The dashboard's copy is a white silhouette for the dark UI and would
  /// be invisible on this page.
  static pw.MemoryImage? _logo;

  static Future<pw.MemoryImage> _loadLogo() async {
    final held = _logo;
    if (held != null) return held;

    final data = await rootBundle.load('assets/icons/cm_lockup_light.png');
    final image = pw.MemoryImage(data.buffer.asUint8List());
    _logo = image;
    return image;
  }

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
    final theme = await _loadTheme();
    final logo = await _loadLogo();

    final doc = pw.Document(
      theme: theme,
      title: '${v.farmName} \u2014 farm evaluation',
      author: "Farmer's Choice \u00B7 CM Beef",
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(38, 36, 38, 30),
        // Page one carries the masthead, so the running header only starts
        // on page two — otherwise the farm name appears twice within an
        // inch of itself.
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                padding: const pw.EdgeInsets.only(bottom: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: _rule, width: 0.6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(v.farmName,
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: _muted,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text('Farm evaluation report',
                        style:
                            const pw.TextStyle(fontSize: 9, color: _muted)),
                  ],
                ),
              ),
        footer: _footer,
        build: (context) => [
          _masthead(v, logo),
          pw.SizedBox(height: 18),
          _facts(v),
          pw.SizedBox(height: 16),
          _scoreBlock(v),
          pw.SizedBox(height: 16),
          _herdBlock(v),
          pw.SizedBox(height: 20),
          ..._sectionBlock(v),
          ..._notesBlocks(v),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------

  static pw.Widget _masthead(Evaluation v, pw.MemoryImage logo) {
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
                  pw.Text('FARM VISIT REPORT',
                      style: pw.TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.4,
                          color: _green,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 9),
                  pw.Text(v.farmName,
                      style: pw.TextStyle(
                          fontSize: 22, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            // start, not end: the column is still parked on the right of
            // the row, but the caption now lines up with the left edge of
            // the lockup above it rather than its right.
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Height only. The lockup is about 3.9:1, so constraining
                // the width instead would shrink it to a sliver.
                pw.Image(logo, height: 30),
                pw.SizedBox(height: 7),
                pw.Text('RANCH EVALUATOR',
                    style: pw.TextStyle(
                        fontSize: 7,
                        letterSpacing: 1.2,
                        color: _muted,
                        fontWeight: pw.FontWeight.bold)),
              ],
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
                width: 92,
                child: pw.Text(label,
                    style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
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
          row('Date of visit', Fmt.date(v.evaluationDate)),
          row('Visited by', v.eoName),
        ],
      ),
    );
  }

  static pw.Widget _scoreBlock(Evaluation v) {
    final color = _forBand(v.band);

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
              color: _wash(color, 0.88),
              border: pw.Border.all(color: _wash(color, 0.45)),
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

  /// The herd as counted on this visit — its own block now rather than one
  /// crammed line in the facts box. It is the figure a farmer checks first.
  static pw.Widget _herdBlock(Evaluation v) {
    pw.Widget cell(String label, int value, {bool emphasis = false}) =>
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(Fmt.thousands(value),
                  style: pw.TextStyle(
                      fontSize: emphasis ? 17 : 15,
                      fontWeight: pw.FontWeight.bold,
                      color: emphasis ? _green : _ink)),
              pw.SizedBox(height: 3),
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
            ],
          ),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _rule),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('HERD AT THIS VISIT',
              style: pw.TextStyle(
                  fontSize: 8, letterSpacing: 1.1, color: _muted)),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              cell('Breeding cows', v.breedingCows),
              cell('Bulls', v.bulls),
              cell('Calves', v.calves),
              cell('Growers / steers', v.growersSteers),
              cell('Total head', v.totalHerd, emphasis: true),
            ],
          ),
        ],
      ),
    );
  }

  /// Every section, with the individual findings underneath it.
  ///
  /// The summary-only version ("Feeding 4/5") tested as thin: a farmer
  /// could see a score but not what produced it, so there was nothing to
  /// act on. Each stored answer id is looked up in EvaluationTemplate and
  /// printed as the question it came from.
  ///
  /// Returned flat so MultiPage can break between findings rather than
  /// pushing a whole section to the next page.
  static List<pw.Widget> _sectionBlock(Evaluation v) {
    final keys = Sections.keys.where(v.sections.containsKey).toList();
    if (keys.isEmpty) return const [];

    final out = <pw.Widget>[_heading('Section findings'), pw.SizedBox(height: 10)];

    for (final key in keys) {
      final section = v.sections[key]!;
      out.add(_sectionHeader(Sections.label(key), section.score));
      out.add(pw.SizedBox(height: 5));
      out.addAll(_answerRows(v, key, section));
      out.add(pw.SizedBox(height: 13));
    }

    out.add(pw.SizedBox(height: 6));
    return out;
  }

  /// Section name, the five blocks, and the score.
  static pw.Widget _sectionHeader(String label, int score) {
    final color = _forSection(score);

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ),
          // Five blocks rather than a number alone — the farmer reads the
          // shape before they read the digit.
          pw.Row(
            children: [
              for (var n = 1; n <= 5; n++)
                pw.Container(
                  width: 22,
                  height: 6,
                  margin: const pw.EdgeInsets.only(right: 3),
                  decoration: pw.BoxDecoration(
                    color: n <= score ? color : _rule,
                    borderRadius: pw.BorderRadius.circular(1.5),
                  ),
                ),
            ],
          ),
          pw.SizedBox(width: 8),
          pw.SizedBox(
            width: 34,
            child: pw.Text('$score / 5',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
          ),
        ],
      ),
    );
  }

  /// Turns the stored answer ids back into readable lines, using the same
  /// templates the officer's screens were built from. This is why answer
  /// ids are never renamed: change one and old reports stop being able to
  /// describe themselves.
  static List<pw.Widget> _answerRows(
      Evaluation v, String key, SectionResult section) {
    if (key == 'vaccination') return _vaccinationRows(v);

    final answers = section.answers;

    if (key == 'performance') {
      final rows = <pw.Widget>[
        // containsKey, not a truth test: ear_tags was added after the
        // first v2 visits, so on those it is ABSENT rather than false.
        // Printing "No" would invent a finding nobody recorded.
        for (final q in EvaluationTemplate.performanceChecks)
          if (answers.containsKey(q.id))
            _finding(q.text, answers[q.id] == true ? 'Yes' : 'No',
                good: answers[q.id] == true),
      ];

      // The measured figures are recorded but not scored, so they are set
      // apart from the practices above them.
      final figures = <pw.Widget>[];
      EvaluationTemplate.performanceKpis.forEach((id, meta) {
        if (answers[id] != null) {
          figures.add(
              _finding('${meta[0]} (${meta[1]})', '${answers[id]}',
                  neutral: true));
        }
      });
      if (figures.isNotEmpty) {
        rows.add(pw.SizedBox(height: 5));
        rows.add(pw.Text('Recorded figures',
            style: pw.TextStyle(
                fontSize: 8, letterSpacing: 0.8, color: _muted)));
        rows.add(pw.SizedBox(height: 3));
        rows.addAll(figures);
      }
      return rows;
    }

    if (key == 'records') {
      // Unconditional, unlike performance: all five record types have
      // always been asked, so a missing answer means the record is not
      // kept — and that absence is the finding.
      return [
        for (final r in EvaluationTemplate.recordTypes)
          _finding(r.text, answers[r.id] == true ? 'Kept' : 'Not kept',
              good: answers[r.id] == true),
      ];
    }

    final template = EvaluationTemplate.forKey(key);
    if (template == null) return const [];

    return [
      for (final q in template.questions)
        if (answers.containsKey(q.id))
          _finding(
            q.text,
            answers[q.id] == true
                ? template.positiveLabel
                : template.negativeLabel,
            good: answers[q.id] == true,
          ),
    ];
  }

  /// One question and its answer.
  static pw.Widget _finding(String label, String value,
      {bool? good, bool neutral = false}) {
    final color =
        neutral || good == null ? _ink : (good ? _green : _ramp[0]);

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // A dot rather than a tick or cross: the answer word already
          // carries the verdict, and two markers for one finding reads as
          // clutter on paper.
          pw.Container(
            width: 3,
            height: 3,
            margin: const pw.EdgeInsets.only(top: 4, left: 2, right: 9),
            decoration: pw.BoxDecoration(
              color: neutral ? _rule : color,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(label,
                style: const pw.TextStyle(fontSize: 9.5, color: _ink)),
          ),
          pw.SizedBox(width: 10),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9.5,
                  color: color,
                  fontWeight:
                      neutral ? pw.FontWeight.normal : pw.FontWeight.bold)),
        ],
      ),
    );
  }

  /// The vaccination record, printed inside its own section rather than
  /// floating below all seven.
  ///
  /// Iterated, never indexed: FMD, LSD and anthrax are mandatory but
  /// brucellosis is optional and omitted entirely when not assessed, so
  /// the array length varies. Officers can also add their own diseases.
  static List<pw.Widget> _vaccinationRows(Evaluation v) {
    if (v.vaccinations.isEmpty) {
      return [
        _finding('No vaccination information recorded', '\u2014',
            neutral: true),
      ];
    }

    return [
      for (final s in v.vaccinations) _vaccinationRow(s),
    ];
  }

  static pw.Widget _vaccinationRow(Vaccination s) {
    final notDone = s.frequency == 'not_done';

    // "The farmer cannot recall" is a different answer from "never
    // given", and the model keeps them apart. So does this.
    final last = s.dateUnknown
        ? 'Farmer unsure'
        : (s.lastAdministered == null
            ? '\u2014'
            : Fmt.date(s.lastAdministered));

    final frequency =
        EvaluationTemplate.vaccinationFrequencies[s.frequency] ??
            Fmt.humanise(s.frequency);

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 3,
            height: 3,
            margin: const pw.EdgeInsets.only(top: 4, left: 2, right: 9),
            decoration: pw.BoxDecoration(
              color: notDone ? _ramp[0] : _green,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(s.disease,
                style: const pw.TextStyle(fontSize: 9.5, color: _ink)),
          ),
          pw.SizedBox(
            width: 92,
            child: pw.Text(last,
                style: pw.TextStyle(
                    fontSize: 9,
                    color: s.dateUnknown ? _muted : _ink)),
          ),
          pw.SizedBox(
            width: 78,
            child: pw.Text(
              frequency,
              textAlign: pw.TextAlign.right,
              // A "Not done" prints red — that absence is the finding.
              style: pw.TextStyle(
                  fontSize: 9.5,
                  color: notDone ? _ramp[0] : _ink,
                  fontWeight:
                      notDone ? pw.FontWeight.bold : pw.FontWeight.normal),
            ),
          ),
          pw.SizedBox(
            width: 54,
            child: pw.Text(
              s.recordsAvailable ? 'On file' : 'No records',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 8,
                  color: s.recordsAvailable ? _green : _muted),
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _notesBlocks(Evaluation v) {
    final out = <pw.Widget>[];

    if (v.keyStrengths.isNotEmpty) {
      out.addAll(_bulletBlock('What is working well', v.keyStrengths, _green));
      out.add(pw.SizedBox(height: 14));
    }
    if (v.areasImprovement.isNotEmpty) {
      out.addAll(_bulletBlock('Areas to improve', v.areasImprovement,
          const PdfColor.fromInt(0xFFC9A227)));
      out.add(pw.SizedBox(height: 14));
    }
    if (v.recommendations.isNotEmpty) {
      out.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(13),
          // No borderRadius here on purpose. dart_pdf asserts that a
          // radius may only accompany a UNIFORM border, and this one is
          // left-only — it cannot round a corner where a 3pt edge meets a
          // zero-width one. Flutter tolerates the same combination on
          // screen, which is why it survived in the dashboard.
          decoration: const pw.BoxDecoration(
            color: _tint,
            border: pw.Border(
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

    return out;
  }

  static List<pw.Widget> _bulletBlock(
      String title, List<String> items, PdfColor accent) {
    return [
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
    ];
  }

  static pw.Widget _heading(String text) => pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
            fontSize: 8.5,
            letterSpacing: 1.2,
            color: _muted,
            fontWeight: pw.FontWeight.bold),
      );

  static pw.Widget _footer(pw.Context context) {
    return pw.Column(
      children: [
        pw.Container(height: 0.6, color: _rule),
        pw.SizedBox(height: 7),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated ${Fmt.date(DateTime.now())} \u00B7 '
              'Choice Meats Ltd \u00D7 Ranch Evaluator',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
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