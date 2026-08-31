import 'package:flutter/material.dart';

import '../models/farm.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Which farms joined the register in this period, and who put them there.
///
/// Opened from the Overview's farms-registered tile. The tile answers "how
/// many farms exist"; this answers "how fast is the register growing, and
/// which officers are growing it".
class FarmsDialog extends StatelessWidget {
  const FarmsDialog({
    super.key,
    required this.rows,
    required this.totalFarms,
    required this.undated,
    required this.periodLabel,
    required this.allTime,
  });

  /// Farms registered inside the window, newest first.
  final List<Farm> rows;

  /// Every farm on the register, windowed or not. Shown in the header so
  /// the dialog's row count never looks like it contradicts the tile.
  final int totalFarms;

  /// Farms with no created_at. Early pilot documents predate the field, so
  /// they cannot be placed in any period — counted in [totalFarms], absent
  /// from [rows], and disclosed rather than quietly dropped.
  final int undated;

  final String periodLabel;

  /// On "all time" there is no such thing as a new farm, so the framing
  /// changes from growth to inventory.
  final bool allTime;

  static Future<void> show(
    BuildContext context, {
    required List<Farm> allFarms,
    required DateTime? cutoff,
    required String periodLabel,
  }) {
    return showDialog(
      context: context,
      builder: (_) => FarmsDialog(
        rows: registeredSince(allFarms, cutoff),
        totalFarms: allFarms.length,
        undated: allFarms.where((f) => f.createdAt == null).length,
        periodLabel: periodLabel,
        allTime: cutoff == null,
      ),
    );
  }

  /// Farms registered on or after [cutoff], newest first. A null cutoff
  /// means "all time" and returns everything.
  ///
  /// Farms with no created_at are excluded from a windowed view — a farm
  /// with no registration date cannot honestly be claimed as new — but are
  /// kept when there is no window at all.
  static List<Farm> registeredSince(List<Farm> all, DateTime? cutoff) {
    final rows = cutoff == null
        ? [...all]
        : all
            .where((f) =>
                f.createdAt != null && !f.createdAt!.isBefore(cutoff))
            .toList();

    rows.sort((a, b) {
      final x = a.createdAt, y = b.createdAt;
      if (x == null && y == null) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- header ----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(allTime ? 'THE REGISTER' : 'NEWLY REGISTERED',
                            style: AppTheme.eyebrow),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            text: '${rows.length}',
                            style: AppTheme.mono(size: 30)
                                .copyWith(letterSpacing: -1.2, height: 1),
                            children: [
                              TextSpan(
                                text: rows.length == 1 ? '  farm' : '  farms',
                                style: AppTheme.mono(
                                        size: 13, color: AppColors.muted)
                                    .copyWith(letterSpacing: 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          allTime
                              ? '$periodLabel · the whole register'
                              : '$periodLabel · $totalFarms registered '
                                  'overall',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.muted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (rows.isEmpty)
                const Text(
                  'No farms were registered in this period. Widen the date '
                  'range to see earlier registrations.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.text2, height: 1.6),
                )
              else ...[
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
                const SizedBox(height: 16),
                Text('NEWEST FIRST', style: AppTheme.eyebrow),
                const SizedBox(height: 12),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          _FarmRow(
                            farm: rows[i],
                            isLast: i == rows.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              if (undated > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$undated ${undated == 1 ? "farm carries" : "farms carry"} '
                    'no registration date, from before the field existed. '
                    '${undated == 1 ? "It is" : "They are"} counted in the '
                    'register total but cannot be placed in a period.',
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                        height: 1.55),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FarmRow extends StatelessWidget {
  const _FarmRow({required this.farm, required this.isLast});

  final Farm farm;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final place = [farm.subCounty, farm.county]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(farm.name,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  place.isEmpty ? '—' : place,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 12, color: AppColors.muted),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        // Already dashed by the model for legacy docs, so
                        // this never renders "null".
                        farm.createdByName,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.text2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.date(farm.createdAt),
                  style: AppTheme.mono(size: 12, color: AppColors.text)),
              const SizedBox(height: 4),
              Text(Fmt.relative(farm.createdAt),
                  style: AppTheme.mono(size: 10.5, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}