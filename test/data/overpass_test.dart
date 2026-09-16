import 'dart:convert';

import 'package:claimtrek/data/remote/overpass_client.dart';
import 'package:claimtrek/geo/lat_lng.dart';
import 'package:flutter_test/flutter_test.dart';

/// A trimmed but structurally faithful Overpass `out geom` response: two hiking relations, one
/// split across two member ways, plus the noise a real response carries — an unnamed relation,
/// a member with no geometry, and a non-route element.
const String _response = '''
{
  "version": 0.6,
  "elements": [
    {
      "type": "relation",
      "id": 11,
      "members": [
        {
          "type": "way", "ref": 101, "role": "",
          "geometry": [
            {"lat": 50.7200, "lon": 10.4500},
            {"lat": 50.7209, "lon": 10.4500}
          ]
        },
        {
          "type": "way", "ref": 102, "role": "",
          "geometry": [
            {"lat": 50.7209, "lon": 10.4500},
            {"lat": 50.7218, "lon": 10.4500}
          ]
        }
      ],
      "tags": {"name": "Rennsteig", "route": "hiking"}
    },
    {
      "type": "relation",
      "id": 22,
      "members": [
        {"type": "node", "ref": 55, "role": "guidepost"},
        {
          "type": "way", "ref": 201, "role": "",
          "geometry": [
            {"lat": 50.7300, "lon": 10.4600},
            {"lat": 50.7309, "lon": 10.4600}
          ]
        }
      ],
      "tags": {"name": "Hoher Weg", "route": "foot"}
    },
    {
      "type": "relation",
      "id": 33,
      "members": [
        {
          "type": "way", "ref": 301, "role": "",
          "geometry": [
            {"lat": 50.7400, "lon": 10.4700},
            {"lat": 50.7409, "lon": 10.4700}
          ]
        }
      ],
      "tags": {"route": "hiking"}
    },
    {"type": "node", "id": 44, "lat": 50.75, "lon": 10.48, "tags": {"amenity": "bench"}}
  ]
}
''';

void main() {
  List<TrailData> parse(String body) =>
      OverpassClient.parse(jsonDecode(body) as Map<String, dynamic>);

  group('parse', () {
    test('reads named hiking and foot routes, dropping everything else', () {
      final trails = parse(_response);

      expect(trails.map((t) => t.name), ['Rennsteig', 'Hoher Weg']);
      expect(trails.map((t) => t.kind), ['hiking', 'foot']);
    });

    test('an unnamed route is dropped rather than listed as "Path"', () {
      // A row the user cannot identify is worse than no row: the whole reason this queries
      // route relations instead of ways is that every result should mean something.
      expect(parse(_response).any((t) => t.id == 'relation/33'), isFalse);
    });

    test('member ways are joined into one path, in order', () {
      final rennsteig = parse(_response).first;

      expect(rennsteig.path.length, 3, reason: 'shared vertex is not repeated');
      expect(rennsteig.path.first.latitude, closeTo(50.7200, 1e-9));
      expect(rennsteig.path.last.latitude, closeTo(50.7218, 1e-9));
    });

    test('members carrying no geometry are skipped, not treated as a gap', () {
      final hoherWeg = parse(_response)[1];

      expect(hoherWeg.path.length, 2);
    });

    test('length is real metres, not a vertex count', () {
      // 0.0018 degrees of latitude at 111320 m/deg is almost exactly 200 m.
      expect(parse(_response).first.lengthM, closeTo(200.0, 1.0));
    });

    test('out-of-order and reversed members still chain into one path', () {
      // Route relations do not store their members in walking order, and many are reversed.
      // Taken as they come, the gap between one member's end and the next member's start is
      // drawn as a straight chord across the map and counted in the length.
      const scrambled = '''
{
  "elements": [
    {
      "type": "relation",
      "id": 77,
      "members": [
        {
          "type": "way", "ref": 3, "role": "",
          "geometry": [
            {"lat": 50.7218, "lon": 10.4500},
            {"lat": 50.7227, "lon": 10.4500}
          ]
        },
        {
          "type": "way", "ref": 1, "role": "",
          "geometry": [
            {"lat": 50.7200, "lon": 10.4500},
            {"lat": 50.7209, "lon": 10.4500}
          ]
        },
        {
          "type": "way", "ref": 2, "role": "",
          "geometry": [
            {"lat": 50.7218, "lon": 10.4500},
            {"lat": 50.7209, "lon": 10.4500}
          ]
        }
      ],
      "tags": {"name": "Scrambled Way", "route": "hiking"}
    }
  ]
}
''';

      final trail = parse(scrambled).single;

      expect(trail.path.length, 4, reason: 'no vertex repeated at a seam');
      expect(trail.path.first.latitude, closeTo(50.7200, 1e-9));
      expect(trail.path.last.latitude, closeTo(50.7227, 1e-9));
      // Four points spanning 0.0027 degrees of latitude is 300 m. A blind concatenation
      // measures far more, because it walks the phantom chords too.
      expect(trail.lengthM, closeTo(300.0, 1.0));
    });

    test('a member that chains onto nothing is dropped, not bridged', () {
      const detached = '''
{
  "elements": [
    {
      "type": "relation",
      "id": 88,
      "members": [
        {
          "type": "way", "ref": 1, "role": "",
          "geometry": [
            {"lat": 50.7200, "lon": 10.4500},
            {"lat": 50.7209, "lon": 10.4500}
          ]
        },
        {
          "type": "way", "ref": 9, "role": "",
          "geometry": [
            {"lat": 51.9000, "lon": 11.9000},
            {"lat": 51.9009, "lon": 11.9000}
          ]
        }
      ],
      "tags": {"name": "Detached Way", "route": "hiking"}
    }
  ]
}
''';

      final trail = parse(detached).single;

      expect(trail.path.length, 2);
      // Bridging to the stray member would draw a 100 km line across the map and report it
      // as trail length.
      expect(trail.lengthM, lessThan(200));
    });

    test('an empty element list yields no trails rather than throwing', () {
      expect(parse('{"elements": []}'), isEmpty);
    });

    test('a response with no elements key yields no trails', () {
      // Overpass returns a bare remark object when a query is rejected; that must read as
      // "nothing found", never as a crash on the treks tab.
      expect(parse('{"remark": "runtime error: Query timed out"}'), isEmpty);
    });
  });

  group('query', () {
    test('asks for named hiking and foot relations within the radius', () {
      final query = OverpassClient.buildQuery(
        const LatLng(50.72, 10.45),
        radiusM: 5000,
      );

      expect(query, contains('around:5000,50.72,10.45'));
      expect(query, contains('hiking'));
      expect(query, contains('foot'));
      expect(query, contains('out geom'));
    });
  });
}
