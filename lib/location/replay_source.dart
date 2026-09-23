import 'dart:async';

import '../geo/lat_lng.dart';
import '../geo/projection.dart';
import 'location_source.dart';

/// One parsed GPX track point, before it becomes a [Fix].
class GpxPoint {
  final LatLng point;
  final double? elevationM;
  final DateTime? time;

  const GpxPoint({required this.point, this.elevationM, this.time});
}

/// Plays a recorded GPX track back as if it were live GPS.
///
/// Takes GPX *content* rather than an asset path so parsing and playback stay testable without
/// a Flutter binding — loading the asset is the caller's job.
class ReplaySource implements LocationSource {
  ReplaySource(this.points, {this.speedX = 10, this.accuracyM = 6.0});

  factory ReplaySource.fromGpx(
    String gpx, {
    int speedX = 10,
    double accuracyM = 6.0,
  }) => ReplaySource(parseGpx(gpx), speedX: speedX, accuracyM: accuracyM);

  final List<GpxPoint> points;
  final int speedX;
  final double accuracyM;

  StreamController<Fix>? _controller;
  Timer? _timer;
  int _index = 0;

  @override
  Stream<Fix> start() {
    stop();
    final controller = StreamController<Fix>();
    _controller = controller;
    _index = 0;
    _scheduleNext();
    return controller.stream;
  }

  void _scheduleNext() {
    final controller = _controller;
    if (controller == null || _index >= points.length) {
      _controller?.close();
      _controller = null;
      return;
    }

    final current = points[_index];
    // Honour the recording's own cadence, compressed by speedX, so a track recorded at 2 s
    // intervals does not replay at the same rate as one recorded at 10.
    var gapMs = 1000;
    if (_index > 0) {
      final previous = points[_index - 1];
      final a = previous.time, b = current.time;
      if (a != null && b != null) {
        final delta = b.difference(a).inMilliseconds;
        if (delta > 0) gapMs = delta;
      }
    }

    _timer = Timer(Duration(milliseconds: (gapMs / speedX).round()), () {
      if (_controller == null) return;
      _emit(current);
      _index++;
      _scheduleNext();
    });
  }

  /// Stands in for <time> when the file has none. One second per point.
  static const int _nominalStepMs = 1000;
  int _syntheticClockMs = DateTime.now().millisecondsSinceEpoch;

  void _emit(GpxPoint current) {
    var speedMs = 0.0;
    if (_index > 0) {
      final previous = points[_index - 1];
      final metres = Projection.haversine(previous.point, current.point);
      final a = previous.time, b = current.time;
      final seconds = (a != null && b != null)
          ? b.difference(a).inMilliseconds / 1000.0
          : 1.0;
      if (seconds > 0) speedMs = metres / seconds;
    }

    _controller?.add(
      Fix(
        point: current.point,
        accuracyM: accuracyM,
        speedMs: speedMs,
        altitudeM: current.elevationM,
        // A GPX without <time> gets a synthetic clock advancing one second per point — the
        // same interval the speed above already assumes. Wall clock would be wrong here: at
        // 10x the points arrive milliseconds apart, so every leg would imply a teleport and
        // the jump gate would throw the whole track away.
        timestampMs:
            current.time?.millisecondsSinceEpoch ??
            (_syntheticClockMs += _nominalStepMs),
      ),
    );
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final controller = _controller;
    _controller = null;
    await controller?.close();
  }

  // ------------------------------------------------------------------------ parsing

  /// Matches the opening tag only. Body extraction is a separate step: folding it into this
  /// pattern lets a self-closing `<trkpt ... />` be read as an opening tag, whose lazy body
  /// then runs on and swallows the following point.
  static final RegExp _trkptTag = RegExp(r'<trkpt\b([^>]*)>');
  static final RegExp _lat = RegExp(r'''\blat\s*=\s*["']([^"']+)["']''');
  static final RegExp _lon = RegExp(r'''\blon\s*=\s*["']([^"']+)["']''');
  static final RegExp _ele = RegExp(r'<ele>\s*([^<\s]+)\s*</ele>');
  static final RegExp _time = RegExp(r'<time>\s*([^<\s]+)\s*</time>');
  static const String _closeTag = '</trkpt>';

  /// Deliberately regex-based rather than a full XML parse: GPX track points are a flat,
  /// predictable shape, and this avoids a dependency for one fixture format.
  static List<GpxPoint> parseGpx(String gpx) {
    final out = <GpxPoint>[];

    for (final tag in _trkptTag.allMatches(gpx)) {
      final attributes = tag.group(1) ?? '';
      final lat = double.tryParse(_lat.firstMatch(attributes)?.group(1) ?? '');
      final lon = double.tryParse(_lon.firstMatch(attributes)?.group(1) ?? '');
      if (lat == null || lon == null) continue;

      var body = '';
      if (!attributes.trimRight().endsWith('/')) {
        final close = gpx.indexOf(_closeTag, tag.end);
        if (close != -1) body = gpx.substring(tag.end, close);
      }

      out.add(
        GpxPoint(
          point: LatLng(lat, lon),
          elevationM: double.tryParse(_ele.firstMatch(body)?.group(1) ?? ''),
          time: DateTime.tryParse(_time.firstMatch(body)?.group(1) ?? ''),
        ),
      );
    }
    return out;
  }
}
