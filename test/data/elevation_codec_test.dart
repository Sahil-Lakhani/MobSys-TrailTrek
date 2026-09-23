import 'package:claimtrek/data/local/elevation_codec.dart';
import 'package:test/test.dart';

void main() {
  test('a profile round-trips', () {
    const samples = [
      ElevationSample(distanceM: 0, altitudeM: 212.4),
      ElevationSample(distanceM: 118.3, altitudeM: 215.9),
      ElevationSample(distanceM: 240.75, altitudeM: 209.1),
    ];

    final restored = ElevationCodec.decode(ElevationCodec.encode(samples));

    expect(restored, hasLength(3));
    for (var i = 0; i < samples.length; i++) {
      // One decimal is 10 cm — far past what a barometer resolves. Rounding to one place can
      // move a value by a full half-step, so the tolerance has to sit just above 0.05.
      expect(restored[i].distanceM, closeTo(samples[i].distanceM, 0.051));
      expect(restored[i].altitudeM, closeTo(samples[i].altitudeM, 0.051));
    }
  });

  test('an empty profile round-trips to empty', () {
    expect(ElevationCodec.encode(const []), '');
    expect(ElevationCodec.decode(''), isEmpty);
    expect(ElevationCodec.decode('   '), isEmpty);
  });

  test('a corrupt sample costs one point, not the whole profile', () {
    // Same bargain PathCodec strikes: a mangled pair should not erase the run.
    final restored = ElevationCodec.decode('0,200;garbage;50,205;;100,210');
    expect(restored, hasLength(3));
    expect(restored.first.altitudeM, closeTo(200, 1e-9));
    expect(restored.last.distanceM, closeTo(100, 1e-9));
  });

  test('altitude below sea level survives', () {
    // The Dead Sea shore is -430 m. A sign dropped here would read as a cliff.
    const samples = [
      ElevationSample(distanceM: 0, altitudeM: -430.5),
      ElevationSample(distanceM: 90, altitudeM: -428.2),
    ];
    final restored = ElevationCodec.decode(ElevationCodec.encode(samples));
    expect(restored[0].altitudeM, closeTo(-430.5, 0.051));
    expect(restored[1].altitudeM, closeTo(-428.2, 0.051));
  });
}
