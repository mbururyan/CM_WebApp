import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/config_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/panel.dart';

/// Admin-only: scoring thresholds and the deletions log.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppConfig _draft;
  bool _saving = false;

  late Future<List<DeletionEntry>> _log;

  @override
  void initState() {
    super.initState();
    _draft = ConfigService.current;
    _log = AdminService.deletionLog();
  }

  bool get _dirty =>
      _draft.excellentMin != ConfigService.current.excellentMin ||
      _draft.goodMin != ConfigService.current.goodMin ||
      _draft.fairMin != ConfigService.current.fairMin ||
      _draft.overdueDays != ConfigService.current.overdueDays;

  Future<void> _save() async {
    final problem = _draft.validate();
    if (problem != null) {
      _toast(problem, bad: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ConfigService.save(_draft);
      if (!mounted) return;
      _toast('Saved. Every score is re-banded on the next page load.');
      setState(() {});
    } catch (e) {
      if (mounted) _toast('Could not save: $e', bad: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, {bool bad = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bad ? const Color(0xFF2A1512) : AppColors.fill,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          title: 'Rating bands',
          note: 'Scores are stored raw and banded when read, so changing '
              'these re-labels every visit already recorded. Nothing is '
              'rewritten and nothing is lost.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BandPreview(config: _draft),
              const SizedBox(height: 20),
              _NumberRow(
                label: 'Excellent starts at',
                value: _draft.excellentMin,
                min: 2,
                max: 35,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(excellentMin: v)),
              ),
              _NumberRow(
                label: 'Good starts at',
                value: _draft.goodMin,
                min: 2,
                max: 34,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(goodMin: v)),
              ),
              _NumberRow(
                label: 'Fair starts at',
                value: _draft.fairMin,
                min: 1,
                max: 33,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(fairMin: v)),
              ),
              const SizedBox(height: 6),
              Text(
                'Anything below ${_draft.fairMin} is Poor.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Panel(
          title: 'Overdue threshold',
          note: 'A farm counts as needing a visit once its newest visit is '
              'older than this.',
          child: _NumberRow(
            label: 'Days without a visit',
            value: _draft.overdueDays,
            min: 7,
            max: 365,
            step: 15,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(overdueDays: v)),
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            FilledButton(
              onPressed: _dirty && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save changes'),
            ),
            const SizedBox(width: 10),
            if (_dirty)
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() => _draft = ConfigService.current),
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: const Text('Discard'),
              ),
          ],
        ),
        const SizedBox(height: 24),

        Panel(
          title: 'Deletions log',
          note: 'Every deleted record, newest first. Append-only — nobody, '
              'including an admin, can edit or clear this.',
          child: FutureBuilder<List<DeletionEntry>>(
            future: _log,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.greenLight),
                    ),
                  ),
                );
              }

              if (snap.hasError) {
                return Text(
                  'Could not read the log. ${snap.error}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.muted, height: 1.6),
                );
              }

              final entries = snap.data ?? const <DeletionEntry>[];
              if (entries.isEmpty) {
                return const Text(
                  'Nothing has been deleted.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    _LogRow(
                      entry: entries[i],
                      isLast: i == entries.length - 1,
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The four bands drawn to scale across 0–35, so the effect of a change is
/// visible before it is saved.
class _BandPreview extends StatelessWidget {
  const _BandPreview({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final poor = config.fairMin;
    final fair = (config.goodMin - config.fairMin).clamp(0, 35);
    final good = (config.excellentMin - config.goodMin).clamp(0, 35);
    final excellent = (36 - config.excellentMin).clamp(0, 35);

    Widget seg(int flex, Color c) =>
        flex <= 0 ? const SizedBox.shrink() : Expanded(flex: flex, child: Container(color: c));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                seg(poor, AppColors.scoreRamp[0]),
                seg(fair, AppColors.scoreRamp[2]),
                seg(good, AppColors.scoreRamp[3]),
                seg(excellent, AppColors.scoreRamp[4]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _Key('Poor', 'below ${config.fairMin}', AppColors.scoreRamp[0]),
            _Key('Fair', '${config.fairMin}–${config.goodMin - 1}',
                AppColors.scoreRamp[2]),
            _Key('Good', '${config.goodMin}–${config.excellentMin - 1}',
                AppColors.scoreRamp[3]),
            _Key('Excellent', '${config.excellentMin}–35',
                AppColors.scoreRamp[4]),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.label, this.range, this.color);

  final String label;
  final String range;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(fontSize: 12.5, color: AppColors.text2)),
        const SizedBox(width: 6),
        Text(range, style: AppTheme.mono(size: 11.5, color: AppColors.muted)),
      ],
    );
  }
}

/// Stepper rather than a text field: a threshold is a small integer, and
/// typing invites empty strings and stray letters that all need handling.
class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.fill,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Step(
                  icon: Icons.remove,
                  enabled: value - step >= min,
                  onTap: () => onChanged(value - step),
                ),
                SizedBox(
                  width: 46,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: AppTheme.mono(size: 14),
                  ),
                ),
                _Step(
                  icon: Icons.add,
                  enabled: value + step <= max,
                  onTap: () => onChanged(value + step),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 16),
      color: AppColors.text2,
      disabledColor: const Color(0xFF3A3A3A),
      hoverColor: AppColors.surface,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry, required this.isLast});

  final DeletionEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isFarm = entry.collection == 'farms';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFF262626))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isFarm ? AppColors.amberDark : AppColors.fill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isFarm ? 'FARM' : 'VISIT',
              style: AppTheme.mono(
                  size: 9.5,
                  color: isFarm ? AppColors.amber : AppColors.muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.summary.isEmpty ? entry.docId : entry.summary,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    entry.deletedByName,
                    Fmt.relative(entry.deletedAt),
                    if (entry.reason.isNotEmpty) '“${entry.reason}”',
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}