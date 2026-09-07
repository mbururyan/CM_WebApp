import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/evaluation.dart';
import '../services/data_service.dart';
import '../services/photo_urls.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/filter_bar.dart';
import '../widgets/panel.dart';

/// Cattle photographs, browsed by visit.
///
/// Grouped by visit rather than shown as one flat wall on purpose: a
/// photograph of a shed means nothing without knowing whose shed, when,
/// and who took it. The list answers that before you open an image.
///
/// This is the main place photos get looked at — the phone captures them,
/// the Monday meeting consumes them.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late Future<FleetData> _future;

  /// The visit whose photos are open, or null for the list. State rather
  /// than a route, matching the visits screen.
  Evaluation? _open;

  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = DataService.loadAll();
  }

  void _reload() => setState(() {
        _open = null;
        _future = DataService.loadAll();
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FleetData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.greenLight),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Panel(
            title: 'Could not load the gallery',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${snapshot.error}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.text2, height: 1.6)),
                const SizedBox(height: 18),
                OutlinedButton(
                    onPressed: _reload, child: const Text('Try again')),
              ],
            ),
          );
        }

        final query = _search.trim().toLowerCase();
        final visits = snapshot.data!.evaluations
            .where((v) => v.hasPhotos)
            .where((v) =>
                query.isEmpty ||
                v.farmName.toLowerCase().contains(query) ||
                v.eoName.toLowerCase().contains(query) ||
                v.county.toLowerCase().contains(query) ||
                v.subCounty.toLowerCase().contains(query))
            .toList()
              ..sort((a, b) {
                final byDate = b.evaluationDate.compareTo(a.evaluationDate);
                if (byDate != 0) return byDate;
                final x = a.createdAt, y = b.createdAt;
                if (x == null || y == null) return 0;
                return y.compareTo(x);
              });

        final open = _open;
        if (open != null) {
          return _VisitGallery(
            visit: open,
            onBack: () => setState(() => _open = null),
          );
        }

        final search = FilterBar(
          children: [
            FilterSearch(
              hint: 'Search farm, officer or county',
              value: _search,
              onChanged: (v) => setState(() => _search = v),
            ),
          ],
        );

        if (visits.isEmpty) {
          // Two different empty states. "Nothing here yet" and "nothing
          // matches what you typed" are not the same message, and the
          // search box has to stay on screen for the second or there is no
          // way to undo the query.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (query.isNotEmpty) ...[
                search,
                const SizedBox(height: 14),
              ],
              Panel(
                title: query.isEmpty
                    ? 'No photographs yet'
                    : 'No matching visits',
                note: query.isEmpty
                    ? 'Cattle photographs captured during farm visits.'
                    : null,
                child: Text(
                  query.isEmpty
                      ? 'Once field officers attach photos to an evaluation, '
                          'every visit with images appears here.'
                      : 'No visit with photographs matches '
                          '\u201C$_search\u201D.',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.text2, height: 1.6),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 14),
              child: Text(
                '${visits.length} ${visits.length == 1 ? "visit" : "visits"} '
                'with photographs',
                style: AppTheme.mono(size: 12, color: AppColors.muted),
              ),
            ),
            for (final v in visits) ...[
              _VisitCard(visit: v, onTap: () => setState(() => _open = v)),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

// ----------------------------------------------------------------- list

/// One visit: who and where on the left, the photographs fanned on the
/// right. The fan shows how much is inside without pretending to be a
/// grid — that is what the full view is for.
class _VisitCard extends StatefulWidget {
  const _VisitCard({required this.visit, required this.onTap});

  final Evaluation visit;
  final VoidCallback onTap;

  @override
  State<_VisitCard> createState() => _VisitCardState();
}

class _VisitCardState extends State<_VisitCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final isWide = MediaQuery.sizeOf(context).width >= Layout.wideBreakpoint;
    final place =
        [v.subCounty, v.county].where((s) => s.trim().isNotEmpty).join(', ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hover ? AppColors.fill : AppColors.surface,
            border:
                Border.all(color: _hover ? AppColors.muted : AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v.farmName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(place.isEmpty ? '\u2014' : place,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.text2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      '${Fmt.date(v.evaluationDate)} \u00B7 ${v.eoName}',
                      style: AppTheme.mono(size: 11, color: AppColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    _PhotoCountChip(visit: v),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _PhotoFan(
                photos: v.photos,
                height: isWide ? 84 : 64,
                maxShown: isWide ? 5 : 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoCountChip extends StatelessWidget {
  const _PhotoCountChip({required this.visit});

  final Evaluation visit;

  @override
  Widget build(BuildContext context) {
    final shown = visit.visiblePhotos.length;
    final queued = visit.queuedPhotoCount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.photo_library_outlined,
            size: 13, color: AppColors.muted),
        const SizedBox(width: 6),
        Text('$shown ${shown == 1 ? "photo" : "photos"}',
            style: AppTheme.mono(size: 11, color: AppColors.text2)),
        if (queued > 0) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              border:
                  Border.all(color: AppColors.amber.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$queued waiting to upload',
                style: AppTheme.mono(size: 9.5, color: AppColors.amber)),
          ),
        ],
      ],
    );
  }
}

/// Overlapping thumbnails.
class _PhotoFan extends StatelessWidget {
  const _PhotoFan({
    required this.photos,
    required this.height,
    required this.maxShown,
  });

  final List<EvaluationPhoto> photos;
  final double height;
  final int maxShown;

  @override
  Widget build(BuildContext context) {
    final shown = photos.take(maxShown).toList();
    final extra = photos.length - shown.length;

    final tile = height * 0.8;
    final step = tile * 0.62; // overlap, so a stack reads as a stack
    final width = shown.isEmpty ? 0.0 : tile + step * (shown.length - 1);

    return SizedBox(
      height: height,
      width: width + (extra > 0 ? 36 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              top: (height - tile) / 2,
              child: Container(
                width: tile,
                height: tile,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  // Bordered in the page background rather than a line
                  // colour, so overlapping tiles separate cleanly.
                  border: Border.all(color: AppColors.bg, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: _Thumb(photo: shown[i]),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: width + 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text('+$extra',
                    style: AppTheme.mono(size: 12, color: AppColors.muted)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single image, or an honest placeholder when it has not uploaded.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo});

  final EvaluationPhoto photo;

  @override
  Widget build(BuildContext context) {
    if (photo.isQueued) {
      return const ColoredBox(
        color: AppColors.fill,
        child: Center(
          child: Icon(Icons.cloud_upload_outlined,
              size: 15, color: AppColors.amber),
        ),
      );
    }

    return _ResolvedImage(
      stored: photo.url!,
      fit: BoxFit.cover,
      placeholder: const ColoredBox(color: AppColors.fill),
      onError: const ColoredBox(
        color: AppColors.fill,
        child: Center(
          child: Icon(Icons.broken_image_outlined,
              size: 15, color: AppColors.muted),
        ),
      ),
    );
  }
}

/// An image whose url may still need fetching from Storage.
///
/// Renders straight away when the url is already resolved or was stored as
/// https, so a scroll back up the page does not flash placeholders.
class _ResolvedImage extends StatefulWidget {
  const _ResolvedImage({
    required this.stored,
    required this.fit,
    required this.placeholder,
    required this.onError,
  });

  final String stored;
  final BoxFit fit;
  final Widget placeholder;
  final Widget onError;

  @override
  State<_ResolvedImage> createState() => _ResolvedImageState();
}

class _ResolvedImageState extends State<_ResolvedImage> {
  String? _url;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ResolvedImage old) {
    super.didUpdateWidget(old);
    if (old.stored != widget.stored) {
      _url = null;
      _failed = false;
      _load();
    }
  }

  void _load() {
    final ready = PhotoUrls.cached(widget.stored);
    if (ready != null) {
      _url = ready;
      return;
    }
    PhotoUrls.resolve(widget.stored).then((url) {
      if (mounted) setState(() => _url = url);
    }).catchError((_) {
      // A failure here is a Storage rules or missing-object problem, not
      // a broken widget. Show the same fallback as a failed fetch.
      if (mounted) setState(() => _failed = true);
      return '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.onError;
    final url = _url;
    if (url == null) return widget.placeholder;

    return Image.network(
      url,
      fit: widget.fit,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : widget.placeholder,
      errorBuilder: (context, error, stack) => widget.onError,
    );
  }
}

// --------------------------------------------------------------- detail

/// Every photograph from one visit, with the context above it.
class _VisitGallery extends StatelessWidget {
  const _VisitGallery({required this.visit, required this.onBack});

  final Evaluation visit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1080 ? 4 : (width >= 700 ? 3 : 2);
    final place = [visit.subCounty, visit.county]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');
    final shown = visit.visiblePhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackLink(onTap: onBack),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visit.farmName,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 7),
                  Text(
                    '${place.isEmpty ? "\u2014" : place} \u00B7 '
                    '${Fmt.date(visit.evaluationDate)} \u00B7 ${visit.eoName}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.text2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            _ScoreBadge(visit: visit),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _PhotoCountChip(visit: visit),
        ),
        const SizedBox(height: 20),
        if (shown.isEmpty)
          Panel(
            title: 'Nothing uploaded yet',
            child: Text(
              visit.queuedPhotoCount == 1
                  ? 'One photograph is still on the officer\u2019s phone and '
                      'has not reached storage. It appears here once it '
                      'uploads.'
                  : '${visit.queuedPhotoCount} photographs are still on the '
                      'officer\u2019s phone and have not reached storage. '
                      'They appear here once they upload.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.text2, height: 1.6),
            ),
          )
        else
          GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (var i = 0; i < shown.length; i++)
                _GridTile(
                  photo: shown[i],
                  onTap: () => _Lightbox.open(context, shown, i, visit),
                ),
            ],
          ),
      ],
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.visit});

  final Evaluation visit;

  @override
  Widget build(BuildContext context) {
    final colour = AppColors.forTotalScore(visit.totalScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RichText(
          text: TextSpan(
            text: '${visit.totalScore}',
            style: AppTheme.mono(size: 22, color: colour)
                .copyWith(letterSpacing: -0.8),
            children: [
              TextSpan(
                text: ' / 35',
                style: AppTheme.mono(size: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: colour.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(visit.ratingLabel.toUpperCase(),
              style: AppTheme.eyebrow.copyWith(color: colour)),
        ),
      ],
    );
  }
}

class _GridTile extends StatefulWidget {
  const _GridTile({required this.photo, required this.onTap});

  final EvaluationPhoto photo;
  final VoidCallback onTap;

  @override
  State<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends State<_GridTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            border:
                Border.all(color: _hover ? AppColors.muted : AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: _Thumb(photo: widget.photo),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- lightbox

/// One photograph, large, with the rest of the visit a keypress away.
class _Lightbox extends StatefulWidget {
  const _Lightbox({
    required this.photos,
    required this.index,
    required this.visit,
  });

  final List<EvaluationPhoto> photos;
  final int index;
  final Evaluation visit;

  static Future<void> open(
    BuildContext context,
    List<EvaluationPhoto> photos,
    int index,
    Evaluation visit,
  ) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (_) => _Lightbox(photos: photos, index: index, visit: visit),
    );
  }

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late int _i = widget.index;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _step(int by) {
    setState(() {
      var next = (_i + by) % widget.photos.length;
      if (next < 0) next += widget.photos.length;
      _i = next;
    });
  }

  /// Arrow keys as well as the buttons: in the Monday meeting somebody is
  /// driving this from a keyboard while talking, not hunting for a target.
  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) _step(1);
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _step(-1);
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_i];
    final size = MediaQuery.sizeOf(context);
    final many = widget.photos.length > 1;

    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.visit.farmName} \u00B7 '
                    '${Fmt.date(widget.visit.evaluationDate)}',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${_i + 1} / ${widget.photos.length}',
                    style: AppTheme.mono(size: 12, color: AppColors.muted)),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.text2,
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: Row(
                children: [
                  if (many)
                    _NavButton(
                        icon: Icons.chevron_left, onTap: () => _step(-1)),
                  Expanded(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxHeight: size.height * 0.74),
                      child: InteractiveViewer(
                        maxScale: 4,
                        child: _ResolvedImage(
                          stored: photo.url!,
                          fit: BoxFit.contain,
                          placeholder: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.greenLight),
                            ),
                          ),
                          onError: const Center(
                            child: Text('This image could not be loaded.',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.text2)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (many)
                    _NavButton(
                        icon: Icons.chevron_right, onTap: () => _step(1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 30),
      color: AppColors.text2,
      hoverColor: Colors.white10,
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
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, size: 16, color: AppColors.text2),
              SizedBox(width: 9),
              Text('All photographs',
                  style: TextStyle(fontSize: 13, color: AppColors.text2)),
            ],
          ),
        ),
      ),
    );
  }
}