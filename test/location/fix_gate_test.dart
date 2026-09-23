import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/location/fix_gate.dart';
import 'package:claimtrek/location/location_source.dart';
import 'package:test/test.dart';

const origin = LatLng(50.7217, 10.4483);

/// Roughly [metresNorth] north of [origin] — enough for distance maths, not for cartography.
LatLng north(double metresNorth) =>
    LatLng(origin.latitude + metresNorth / 111320.0, origin.longitude);

Fix fix(LatLng point, {required int atMs, double accuracy = 6, double speed = 3}) =>
    Fix(point: point, accuracyM: accuracy, speedMs: speed, timestampMs: atMs);

void main() {
  late FixGate gate;

  setUp(() => gate = FixGate());

  test('the first fix is always taken', () {
    final verdict = gate.admit(fix(origin, atMs: 0));

    expect(verdict.accepted, isTrue);
    expect(verdict.creditsDistance, isFalse, reason: 'nothing to measure from yet');
  });

  test('a normal running step is taken and counted', () {
    gate.admit(fix(origin, atMs: 0));

    final verdict = gate.admit(fix(north(3), atMs: 1000));

    expect(verdict.accepted, isTrue);
    expect(verdict.creditsDistance, isTrue);
  });

  test('a teleport is refused however good its accuracy claims to be', () {
    // The real failure this exists for: multipath between buildings produces a fix that is
    // 80 m out while reporting 6 m accuracy and a plausible speed, so the stateless gate waves
    // it through and the polygon grows a spike.
    gate.admit(fix(origin, atMs: 0));

    final verdict = gate.admit(fix(north(80), atMs: 1000, accuracy: 6, speed: 3));

    expect(verdict.accepted, isFalse);
  });

  test('a refused fix does not become the new reference', () {
    // Otherwise one outlier drags the anchor with it and the real next fix looks like the jump.
    gate.admit(fix(origin, atMs: 0));
    gate.admit(fix(north(80), atMs: 1000));

    final verdict = gate.admit(fix(north(3), atMs: 2000));

    expect(verdict.accepted, isTrue);
  });

  test('a long walk between fixes is fine — it is speed that matters, not distance', () {
    gate.admit(fix(origin, atMs: 0));

    // 60 m in 20 s is 3 m/s. Perfectly ordinary running; only the elapsed time reveals that.
    final verdict = gate.admit(fix(north(60), atMs: 20000));

    expect(verdict.accepted, isTrue);
  });

  test('the gate gives up rather than stranding a runner who really did move', () {
    // A runner who took a tram, or whose receiver re-acquired far away, must not be locked out
    // of their own track forever by a gate that keeps measuring from a stale anchor.
    gate.admit(fix(origin, atMs: 0));

    var verdict = gate.admit(fix(north(800), atMs: 1000));
    expect(verdict.accepted, isFalse);
    verdict = gate.admit(fix(north(805), atMs: 2000));
    expect(verdict.accepted, isFalse);

    verdict = gate.admit(fix(north(810), atMs: 3000));
    expect(verdict.accepted, isTrue, reason: 'resyncs after repeated rejection');
    expect(verdict.creditsDistance, isFalse, reason: 'the gap was never run');
  });

  test('a signal gap is rejoined without crediting the ground in between', () {
    // Two minutes in a tunnel. The point is real and belongs on the track; the straight line
    // back to it is not distance the runner covered, and counting it inflates the run.
    gate.admit(fix(origin, atMs: 0));

    final verdict = gate.admit(fix(north(40), atMs: 120000));

    expect(verdict.accepted, isTrue);
    expect(verdict.creditsDistance, isFalse);
    expect(verdict.brokeTrack, isTrue);
  });

  test('fixes arriving out of order are ignored', () {
    // Some receivers replay a buffered fix after a newer one; a negative interval would make
    // the implied speed negative and sail through every check.
    gate.admit(fix(origin, atMs: 10000));

    final verdict = gate.admit(fix(north(5), atMs: 9000));

    expect(verdict.accepted, isFalse);
  });

  test('two fixes with the same timestamp do not divide by zero', () {
    gate.admit(fix(origin, atMs: 5000));

    final verdict = gate.admit(fix(north(2), atMs: 5000));

    expect(verdict.accepted, isTrue, reason: 'a duplicate instant is not a teleport');
    expect(verdict.creditsDistance, isFalse);
  });

  test('resetting forgets the previous run entirely', () {
    gate.admit(fix(north(800), atMs: 0));
    gate.reset();

    final verdict = gate.admit(fix(origin, atMs: 1000));

    expect(verdict.accepted, isTrue);
  });
}
