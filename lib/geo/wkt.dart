import 'package:clipper2/clipper2.dart';

const String _emptyWkt = 'POLYGON EMPTY';

final RegExp _ringPattern = RegExp(r'\(([^()]*)\)');

String _num(double v) => v.toString();

String _writeRing(PathD ring) {
  final buffer = StringBuffer();
  for (var i = 0; i < ring.length; i++) {
    if (i > 0) buffer.write(', ');
    buffer.write('${_num(ring[i].x)} ${_num(ring[i].y)}');
  }
  if (ring.isNotEmpty && ring.first != ring.last) {
    buffer.write(', ${_num(ring.first.x)} ${_num(ring.first.y)}');
  }
  return '($buffer)';
}

List<List<PathD>> groupIntoPolygons(PathsD paths) {
  final rings = paths.where((r) => r.length >= 3).toList();
  if (rings.isEmpty) return const [];

  final depths = List<int>.generate(rings.length, (i) => _depthOf(rings, i));

  final polygons = <List<PathD>>[];
  final polygonOfRing = <int, int>{};

  for (var i = 0; i < rings.length; i++) {
    if (depths[i].isEven) {
      polygonOfRing[i] = polygons.length;
      polygons.add([rings[i]]);
    }
  }

  for (var i = 0; i < rings.length; i++) {
    if (depths[i].isOdd) {
      for (var j = 0; j < rings.length; j++) {
        if (i != j &&
            depths[j] == depths[i] - 1 &&
            _containsPoint(rings[j], rings[i].first)) {
          final target = polygonOfRing[j];
          if (target != null) polygons[target].add(rings[i]);
          break;
        }
      }
    }
  }
  return polygons;
}

int _depthOf(List<PathD> rings, int index) {
  var depth = 0;
  for (var j = 0; j < rings.length; j++) {
    if (index != j && _containsPoint(rings[j], rings[index].first)) depth++;
  }
  return depth;
}

String writeWkt(PathsD paths) {
  if (paths.isEmpty) return _emptyWkt;

  final polygons = groupIntoPolygons(paths);
  if (polygons.isEmpty) return _emptyWkt;

  if (polygons.length == 1) {
    return 'POLYGON (${polygons.single.map(_writeRing).join(', ')})';
  }
  final bodies = polygons
      .map((rings) => '(${rings.map(_writeRing).join(', ')})')
      .join(', ');
  return 'MULTIPOLYGON ($bodies)';
}

PathsD? readWkt(String wkt) {
  final text = wkt.trim();
  final upper = text.toUpperCase();
  if (!upper.startsWith('POLYGON') && !upper.startsWith('MULTIPOLYGON')) {
    return null;
  }
  if (upper.contains('EMPTY')) return <PathD>[];

  try {
    final rings = <PathD>[];
    var sawRingGroup = false;

    for (final match in _ringPattern.allMatches(text)) {
      final body = match.group(1)!.trim();
      if (body.isEmpty) continue;
      sawRingGroup = true;

      final ring = <PointD>[];
      for (final pair in body.split(',')) {
        final parts = pair.trim().split(RegExp(r'\s+'));
        if (parts.length < 2) return null;
        ring.add(PointD(double.parse(parts[0]), double.parse(parts[1])));
      }
      if (ring.length > 1 && ring.first == ring.last) ring.removeLast();
      if (ring.length >= 3) rings.add(ring);
    }
    if (!sawRingGroup) return null;
    if (rings.isEmpty) return <PathD>[];

    return _orient(rings);
  } catch (_) {
    return null;
  }
}

PathsD _orient(List<PathD> rings) {
  final out = <PathD>[];
  for (var i = 0; i < rings.length; i++) {
    final shouldBePositive = _depthOf(rings, i).isEven;
    final ring = rings[i];
    final isPositive = ring.area > 0;
    out.add(isPositive == shouldBePositive ? ring : ring.reversed.toList());
  }
  return out;
}

bool _containsPoint(PathD ring, PointD p) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}
