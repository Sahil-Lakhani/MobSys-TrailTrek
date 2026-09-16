import 'package:claimtrek/data/local/path_codec.dart';
import 'package:claimtrek/geo/lat_lng.dart';
import 'package:test/test.dart';

void main() {
  test('a track round-trips', () {
    const track = [
      LatLng(50.7217, 10.4483),
      LatLng(50.7218122, 10.4490094),
      LatLng(50.72165, 10.44795),
    ];

    final restored = PathCodec.decode(PathCodec.encode(track));

    expect(restored, hasLength(3));
    for (var i = 0; i < track.length; i++) {
      // Six decimals is about 10 cm, well past what a receiver resolves.
      expect(restored[i].latitude, closeTo(track[i].latitude, 1e-6));
      expect(restored[i].longitude, closeTo(track[i].longitude, 1e-6));
    }
  });

  test('an empty track round-trips to empty', () {
    expect(PathCodec.encode(const []), '');
    expect(PathCodec.decode(''), isEmpty);
    expect(PathCodec.decode('   '), isEmpty);
  });

  test('a corrupt vertex costs one point, not the whole run', () {
    // Losing a run because one pair got mangled would be a poor trade.
    final restored = PathCodec.decode('50.7,10.4;garbage;51.0,10.9;;52.0,11.0');
    expect(restored, hasLength(3));
    expect(restored.first.latitude, closeTo(50.7, 1e-9));
    expect(restored.last.latitude, closeTo(52.0, 1e-9));
  });

  test('negative and zero coordinates survive', () {
    const track = [LatLng(-33.8688, 151.2093), LatLng(0, 0)];
    final restored = PathCodec.decode(PathCodec.encode(track));
    expect(restored[0].latitude, closeTo(-33.8688, 1e-6));
    expect(restored[1].latitude, 0);
    expect(restored[1].longitude, 0);
  });
}
