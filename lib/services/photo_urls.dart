import 'package:firebase_storage/firebase_storage.dart';

/// Turns whatever is stored in a photo's `url` into something a browser
/// can actually fetch.
///
/// The mobile app currently stores the Storage REFERENCE — a
/// `gs://cm-beef-app1/evaluations/.../x.jpg` URI — rather than the result
/// of getDownloadURL(). A gs:// URI is not an HTTP scheme, so Image.network
/// cannot load it and every tile fails.
///
/// Resolving here rather than backfilling Firestore means the photos
/// already recorded work immediately, and an https url passes through
/// untouched — so when the phone starts storing real download URLs this
/// code keeps working with nothing to change.
///
/// The bucket is taken from the URI itself. That matters: the project has
/// two buckets, a default in US-EAST1 and the AFRICA-SOUTH1 one the app
/// actually writes to, and refFromURL reads the name out of the string
/// rather than guessing at a default.
class PhotoUrls {
  PhotoUrls._();

  /// Resolved urls live for the session. Download urls are stable, so
  /// re-resolving on every rebuild would be a round trip per thumbnail
  /// per scroll.
  static final _cache = <String, String>{};

  /// One request per uri even when several tiles ask at once.
  static final _inFlight = <String, Future<String>>{};

  static bool _needsResolving(String stored) => stored.startsWith('gs://');

  /// One Storage handle per bucket.
  ///
  /// FirebaseStorage.instance is bound to the storageBucket in
  /// firebase_options.dart — the US-EAST1 default that Storage creates on
  /// its own. Asking THAT instance to resolve a gs:// URI belonging to the
  /// AFRICA-SOUTH1 bucket is a mismatch, not a lookup, and it throws. So
  /// the bucket is read out of the URI and the matching instance asked
  /// instead. Works for either bucket, and for any future one.
  static final _buckets = <String, FirebaseStorage>{};

  static FirebaseStorage _storageFor(String bucket) => _buckets.putIfAbsent(
      bucket, () => FirebaseStorage.instanceFor(bucket: 'gs://$bucket'));

  /// `gs://cm-beef-app1/evaluations/x/y.jpg` -> `cm-beef-app1`.
  static String? _bucketOf(String uri) {
    final rest = uri.substring('gs://'.length);
    final slash = rest.indexOf('/');
    if (slash <= 0) return null;
    return rest.substring(0, slash);
  }

  /// The already-resolved url, if we have it. Lets a widget render
  /// immediately instead of flashing a placeholder on every rebuild.
  static String? cached(String stored) =>
      _needsResolving(stored) ? _cache[stored] : stored;

  static Future<String> resolve(String stored) {
    if (!_needsResolving(stored)) return Future.value(stored);

    final hit = _cache[stored];
    if (hit != null) return Future.value(hit);

    return _inFlight.putIfAbsent(stored, () async {
      try {
        final bucket = _bucketOf(stored);
        if (bucket == null) {
          throw ArgumentError('Malformed storage uri: $stored');
        }
        final url =
            await _storageFor(bucket).refFromURL(stored).getDownloadURL();
        _cache[stored] = url;
        return url;
      } finally {
        _inFlight.remove(stored);
      }
    });
  }
}