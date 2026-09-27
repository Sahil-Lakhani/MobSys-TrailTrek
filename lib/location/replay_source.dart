import 'dart:async';

import '../geo/lat_lng.dart';
import '../geo/projection.dart';
import 'location_source.dart';

class GpxPoint {
  final LatLng point;
  final double? elevationM;
  final DateTime? time;

  const GpxPoint({required this.point, this.elevationM, this.time});
}

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

  static final RegExp _trkptTag = RegExp(r'<trkpt\b([^>]*)>');
  static final RegExp _lat = RegExp(r'''\blat\s*=\s*["']([^"']+)["']''');
  static final RegExp _lon = RegExp(r'''\blon\s*=\s*["']([^"']+)["']''');
  static final RegExp _ele = RegExp(r'<ele>\s*([^<\s]+)\s*</ele>');
  static final RegExp _time = RegExp(r'<time>\s*([^<\s]+)\s*</time>');
  static const String _closeTag = '</trkpt>';

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
