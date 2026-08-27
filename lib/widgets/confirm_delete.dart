import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Confirmation before a hard delete.
///
/// Returns the typed reason on confirm, or null if cancelled. An empty
/// string is a valid confirm — the reason is encouraged, not required,
/// because a required field just teaches people to type "x".
class ConfirmDelete extends StatefulWidget {
  const ConfirmDelete({
    super.key,
    required this.title,
    required this.subject,
    required this.consequence,
  });

  final String title;

  /// What is being deleted, in the user's own terms.
  final String subject;

  /// What happens as a result. Plain language, no hedging.
  final String consequence;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String subject,
    required String consequence,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => ConfirmDelete(
        title: title,
        subject: subject,
        consequence: consequence,
      ),
    );
  }

  @override
  State<ConfirmDelete> createState() => _ConfirmDeleteState();
}

class _ConfirmDeleteState extends State<ConfirmDelete> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.subject,
                  style: AppTheme.mono(size: 12.5, color: AppColors.text2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.consequence,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.text2, height: 1.6),
              ),
              const SizedBox(height: 16),
              Text('WHY (OPTIONAL)', style: AppTheme.eyebrow),
              const SizedBox(height: 6),
              TextField(
                controller: _reason,
                autofocus: true,
                maxLength: 140,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'e.g. duplicate of the 09:24 visit',
                  isDense: true,
                  counterText: '',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.text2),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_reason.text),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}