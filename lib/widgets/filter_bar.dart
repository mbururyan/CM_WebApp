import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The filter row every list screen sits behind.
///
/// Visits and Farms each grew their own copy of this, and the copies
/// drifted: 48px dropdowns against 44px, labelled against bare, a filled
/// export button against an outlined one. None of those differences was
/// chosen — they are just what happens when the same widget is written
/// twice. One definition means the screens cannot disagree again.
///
/// Lay a row out with [FilterBar], and put [FilterSearch], [FilterSelect]
/// and [FilterExportButton] inside it.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.children});

  final List<Widget> children;

  /// Every control is this tall. The search field and the dropdowns sit on
  /// one line, so a few pixels between them shows up as a wobble.
  static const controlHeight = 46.0;

  static const radius = 10.0;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// Free-text search.
///
/// Holds its own controller so a screen can clear the box from a "reset
/// filters" button — passing text down without one leaves the field
/// showing a query that is no longer being applied.
class FilterSearch extends StatefulWidget {
  const FilterSearch({
    super.key,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.width = 250,
  });

  final String hint;

  /// The query the screen is actually applying. When this changes from
  /// outside — a reset — the field follows it.
  final String value;

  final ValueChanged<String> onChanged;
  final double width;

  @override
  State<FilterSearch> createState() => _FilterSearchState();
}

class _FilterSearchState extends State<FilterSearch> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(FilterSearch old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: FilterBar.controlHeight,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon:
              const Icon(Icons.search, size: 18, color: AppColors.muted),
          suffixIcon: widget.value.isEmpty
              ? null
              : IconButton(
                  onPressed: () => widget.onChanged(''),
                  icon: const Icon(Icons.close, size: 15),
                  color: AppColors.muted,
                  tooltip: 'Clear',
                ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// A labelled dropdown.
///
/// Labelled always, never bare. Four dropdowns in a row all reading "All"
/// tell you nothing about what they filter, which is what the Farms screen
/// looked like before this.
class FilterSelect extends StatelessWidget {
  const FilterSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: FilterBar.controlHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.fill,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(FilterBar.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${label.toUpperCase()}  ', style: AppTheme.eyebrow),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              // Falls back to the first item rather than throwing when a
              // value disappears — a county with no farms left in range
              // stops being an option while still being selected.
              value: items.contains(value) ? value : items.first,
              items: items
                  .map((i) => DropdownMenuItem(
                        value: i,
                        child: Text(i, style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              isDense: true,
              dropdownColor: AppColors.surface,
              borderRadius: BorderRadius.circular(FilterBar.radius),
              icon: const Icon(Icons.expand_more,
                  size: 18, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Export, in the brand green, at the same height as everything beside it.
class FilterExportButton extends StatelessWidget {
  const FilterExportButton({
    super.key,
    required this.onPressed,
    this.label = 'Export to Excel',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: FilterBar.controlHeight,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.download_outlined, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}

/// The shared period options, so "Last 7 days" cannot exist on one screen
/// and not another.
class FilterPeriod {
  FilterPeriod._();

  static const options = <String>[
    'All time',
    'Last 7 days',
    'Last 30 days',
    'Last 90 days',
    'Last year',
  ];

  static String label(int days) => switch (days) {
        7 => 'Last 7 days',
        30 => 'Last 30 days',
        90 => 'Last 90 days',
        365 => 'Last year',
        _ => 'All time',
      };

  static int days(String label) => switch (label) {
        'Last 7 days' => 7,
        'Last 30 days' => 30,
        'Last 90 days' => 90,
        'Last year' => 365,
        _ => 0,
      };
}