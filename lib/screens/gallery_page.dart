import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/panel.dart';

/// Placeholder for the cattle photo gallery.
///
/// The mobile app will attach images to a farm visit; this is where they
/// will be browsed. It exists now so the destination is real in the nav
/// rather than a promise made in a meeting.
class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          title: 'Gallery module coming soon',
          note: 'Cattle photographs captured during farm visits.',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.photo_library_outlined,
                      size: 24, color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                const SizedBox(
                  width: 420,
                  child: Text(
                    'Field officers will be able to photograph cattle during '
                    'an evaluation. Once those images are syncing, this page '
                    'will show them grouped by farm and by visit.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.text2, height: 1.65),
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