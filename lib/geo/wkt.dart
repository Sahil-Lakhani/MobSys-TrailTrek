import 'package:clipper2/clipper2.dart';

/// WKT serialisation for territory rings.
///
/// A territory is a [PathsD]: a flat list of rings where a shell has positive signed area and
/// a hole has negative. That convention is what makes `paths.area` correct without any
/// bookkeeping — and holes are not hypothetical here, since carving a rival's claim out of the
/// middle of your ground produces one.
///
/// WKT keeps the whole shape in one text column, so no schema changes when a polygon gains a
/// lobe or a hole, and the stored value stays readable and portable.

const String _emptyWkt = 'POLYGON EMPTY';

/// Rings are the innermost parenthesised groups in both POLYGON and MULTIPOLYGON.
final RegExp _ringPattern = RegExp(r'\(([^()]*)\)');

/// Shortest representation that parses back to the identical double.
String _num(double v) => v.toString();

String _writeRing(PathD ring) {
  final buffer = StringBuffer();
  for (var i = 0; i < ring.length; i++) {
    if (i > 0) buffer.write(', ');
    buffer.write('${_num(ring[i].x)} ${_num(ring[i].y)}');
  }
  // WKT rings are explicitly closed; clipper paths leave closure implicit.
  if (ring.isNotEmpty && ring.first != ring.last) {
    buffer.write(', ${_num(ring.first.x)} ${_num(ring.first.y)}');
  }
  return '($buffer)';
}

/// Group [paths] into polygons of shell-plus-holes by nesting depth: the first ring of each
/// group is the shell, the rest are its holes. Used both for WKT writing and for rendering,
/// which needs exactly the same grouping.
///
/// Deliberately *not* done with clipper's own `booleanOpPolyTreeD`, which would be the obvious
/// tool: it hardcodes `ClipperD()` and so rounds to two decimal places with no way to override.
/// Territories are written in degrees, where 0.01° is about a kilometre, and the geometry would
/// be destroyed on the way out. Containment analysis is exact at any scale and reuses the same
/// helpers the reader needs anyway.
List<List<PathD>> groupIntoPolygons(PathsD paths) {
  final rings = paths.where((r) => r.length >= 3).toList();
  if (rings.isEmpty) return const [];

  final depths = List<int>.generate(rings.length, (i) => _depthOf(rings, i));

  final polygons = <List<PathD>>[];
  final polygonOfRing = <int, int>{};

  // Even depth is a shell and opens a polygon; a shell nested inside a hole opens its own.
  for (var i = 0; i < rings.length; i++) {
    if (depths[i].isEven) {
      polygonOfRing[i] = polygons.length;
      polygons.add([rings[i]]);
    }
  }

  // Odd depth is a hole; it belongs to the shell that immediately encloses it.
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

/// Returns null rather than throwing on malformed input: WKT reaching this function came out of
/// storage or off a network, and neither is trusted.
PathsD? readWkt(String wkt) {
  final text = wkt.trim();
  final upper = text.toUpperCase();
  if (!upper.startsWith('POLYGON') && !upper.startsWith('MULTIPOLYGON')) {
    return null;
  }
  if (upper.contains('EMPTY')) return <PathD>[];

  try {
    final rings = <PathD>[];
    // Distinguishes "parsed, but the shape is degenerate" from "could not parse at all".
    // Without it a truncated string silently reads as an empty territory, quietly deleting
    // someone's ground instead of reporting corrupt data.
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
      // Drop WKT's explicit closing vertex; clipper paths are implicitly closed.
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

/// Force the sign convention the rest of the code relies on: shells positive, holes negative.
///
/// A ring's role is decided by how many other rings enclose it — odd depth is a hole. That is
/// independent of whatever orientation the producing system happened to write, so WKT from
/// another tool round-trips correctly.
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

/// Ray casting. Used only to establish nesting depth, never for hit-testing.
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
