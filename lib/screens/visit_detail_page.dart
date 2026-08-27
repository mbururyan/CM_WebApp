import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/panel.dart';

/// Read-only view of one visit. Rendered inside the shell rather than
/// pushed as a route, so the sidebar stays put and the back button returns
/// to the filtered table exactly as it was left.
class VisitDetailPage extends StatelessWidget {
  const VisitDetailPage({
    super.key,
    required this.visit,
    required this.onBack,
    this.onDelete,
  });

  final Evaluation visit;
  final VoidCallback onBack;

  /// Null for non-admins — the button is not rendered at all.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= Layout.wideBreakpoint;
    final scoreColor = AppColors.forTotalScore(visit.totalScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackLink(onTap: onBack),
        const SizedBox(height: 16),

        // ---- heading ----
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: isWide ? 420 : double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    visit.farmName,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      visit.county,
                      visit.subCounty,
                      'visited ${Fmt.date(visit.evaluationDate)}',
                      'by ${visit.eoName}',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete visit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: Color(0xFF5A2B26)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),

        // ---- score + herd ----
        _TwoUp(
          isWide: isWide,
          left: Panel(
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('TOTAL SCORE', style: AppTheme.eyebrow),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        text: '${visit.totalScore}',
                        style: AppTheme.mono(
                                size: 38, color: scoreColor)
                            .copyWith(letterSpacing: -1.5, height: 1),
                        children: [
                          TextSpan(
                            text: ' / 35',
                            style: AppTheme.mono(
                                size: 15, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _RatingBadge(band: visit.band, label: visit.ratingLabel),
              ],
            ),
          ),
          right: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('HERD AT THIS VISIT', style: AppTheme.eyebrow),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 22,
                  runSpacing: 12,
                  children: [
                    _Herd('Breeding cows', visit.breedingCows),
                    _Herd('Bulls', visit.bulls),
                    _Herd('Calves', visit.calves),
                    _Herd('Growers / steers', visit.growersSteers),
                    _Herd('Total head', visit.totalHerd,
                        color: AppColors.greenLight),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ---- sections ----
        Panel(
          title: 'Section scores',
          note: 'Expand a section to see the answers behind its score',
          child: Column(
            children: [
              for (final key in Sections.keys)
                if (visit.sections.containsKey(key))
                  _SectionTile(
                    label: Sections.label(key),
                    result: visit.sections[key]!,
                  ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---- vaccinations + summary ----
        _TwoUp(
          isWide: isWide,
          left: Panel(
            title: 'Vaccinations',
            note: visit.vaccinations.isEmpty
                ? 'Nothing recorded'
                : '${visit.vaccinations.length} diseases recorded',
            child: visit.vaccinations.isEmpty
                ? const _Muted('No vaccination rows on this visit.')
                : Column(
                    children: [
                      for (var i = 0; i < visit.vaccinations.length; i++)
                        _VaccRow(
                          v: visit.vaccinations[i],
                          isLast: i == visit.vaccinations.length - 1,
                        ),
                    ],
                  ),
          ),
          right: Panel(
            title: "Officer's summary",
            note: 'The recommendation is the part shared with the farmer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Listed('Strengths', visit.keyStrengths),
                const SizedBox(height: 12),
                _Listed('To improve', visit.areasImprovement),
                const SizedBox(height: 16),
                if (visit.recommendations.isEmpty)
                  const _Muted('No recommendation recorded.')
                else
                  Container(
                    padding: const EdgeInsets.only(left: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(
                            color: AppColors.greenDark, width: 2),
                      ),
                    ),
                    child: Text(
                      visit.recommendations,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.text2,
                          height: 1.65),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Side by side when there's room, stacked when there isn't.
class _TwoUp extends StatelessWidget {
  const _TwoUp({
    required this.isWide,
    required this.left,
    required this.right,
  });

  final bool isWide;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 14), right],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 14),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.arrow_back, size: 16),
        label: const Text('All visits'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.text2,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.band, required this.label});

  final String band;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scores = {
      'excellent': 5,
      'good': 4,
      'fair': 3,
      'poor': 1,
    };
    final color = AppColors.forSectionScore(scores[band] ?? 3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTheme.mono(size: 11, color: color),
      ),
    );
  }
}

class _Herd extends StatelessWidget {
  const _Herd(this.label, this.value, {this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Fmt.thousands(value),
          style: AppTheme.mono(size: 20, color: color ?? AppColors.text),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
      ],
    );
  }
}

/// One section row that expands to reveal its answers.
class _SectionTile extends StatefulWidget {
  const _SectionTile({required this.label, required this.result});

  final String label;
  final SectionResult result;

  @override
  State<_SectionTile> createState() => _SectionTileState();
}

class _SectionTileState extends State<_SectionTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forSectionScore(widget.result.score);
    final hasDetail =
        widget.result.answers.isNotEmpty || widget.result.comment.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF262626))),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: hasDetail ? () => setState(() => _open = !_open) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.label,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  // Five pips: a 1–5 score reads faster than a number alone.
                  Row(
                    children: [
                      for (var n = 1; n <= 5; n++)
                        Container(
                          width: 22,
                          height: 6,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: n <= widget.result.score
                                ? color
                                : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 18,
                    child: Text('${widget.result.score}',
                        textAlign: TextAlign.right,
                        style: AppTheme.mono(size: 13, color: color)),
                  ),
                  SizedBox(
                    width: 26,
                    child: hasDetail
                        ? Icon(
                            _open ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: AppColors.muted,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...widget.result.answers.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              Fmt.humanise(e.key),
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.text2),
                            ),
                          ),
                          _AnswerChip(value: e.value),
                        ],
                      ),
                    ),
                  ),
                  if (widget.result.comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.fill,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('INTERNAL FIELD NOTE',
                              style: AppTheme.eyebrow),
                          const SizedBox(height: 6),
                          Text(
                            widget.result.comment,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.text2,
                                height: 1.55),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Renders a bool as Yes/No and a number as itself. An absent KPI never
/// reaches here — the mobile app omits it rather than writing 0.
class _AnswerChip extends StatelessWidget {
  const _AnswerChip({required this.value});

  final dynamic value;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color color;

    if (value is bool) {
      text = value == true ? 'Yes' : 'No';
      color = value == true ? AppColors.greenLight : AppColors.orange;
    } else if (value is num) {
      text = value.toString();
      color = AppColors.text2;
    } else {
      text = value?.toString() ?? '—';
      color = AppColors.muted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: AppTheme.mono(size: 11, color: color)),
    );
  }
}

class _VaccRow extends StatelessWidget {
  const _VaccRow({required this.v, required this.isLast});

  final Vaccination v;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    // "Cannot recall" is a real answer and shows differently from "blank".
    final dateText = v.dateUnknown
        ? 'Not recalled'
        : (v.lastAdministered == null ? '—' : Fmt.date(v.lastAdministered));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFF262626))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.disease, style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(
                  Fmt.humanise(v.frequency),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              dateText,
              style: AppTheme.mono(
                  size: 11.5,
                  color: v.dateUnknown ? AppColors.muted : AppColors.text2),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: v.recordsAvailable
                  ? AppColors.greenDark
                  : AppColors.fill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              v.recordsAvailable ? 'Records seen' : 'No records',
              style: AppTheme.mono(
                size: 10,
                color: v.recordsAvailable
                    ? AppColors.greenLight
                    : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Listed extends StatelessWidget {
  const _Listed(this.label, this.items);

  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: AppTheme.eyebrow),
        const SizedBox(height: 6),
        if (items.isEmpty)
          const _Muted('None recorded.')
        else
          Text(
            items.join(' · '),
            style: const TextStyle(
                fontSize: 13, color: AppColors.text, height: 1.55),
          ),
      ],
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
      );
}

/// Convenience so callers don't have to repeat the admin check.
VoidCallback? deleteHandlerFor(VoidCallback action) =>
    SessionService.isAdmin ? action : null;