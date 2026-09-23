import 'package:claimtrek/ui/tracking/tracking_controller.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime at(int hour) => DateTime(2026, 9, 24, hour, 30);

void main() {
  test('a run after midnight is a night run, not a morning one', () {
    // The bug this exists for: a bare `hour < 12` calls 00:30 a morning run, which is the one
    // hour nobody would describe that way.
    expect(defaultRunTitle(at(0)), 'Night run');
    expect(defaultRunTitle(at(3)), 'Night run');
  });

  test('the ordinary parts of the day read as you would say them', () {
    expect(defaultRunTitle(at(6)), 'Morning run');
    expect(defaultRunTitle(at(11)), 'Morning run');
    expect(defaultRunTitle(at(12)), 'Afternoon run');
    expect(defaultRunTitle(at(17)), 'Afternoon run');
    expect(defaultRunTitle(at(18)), 'Evening run');
    expect(defaultRunTitle(at(21)), 'Evening run');
  });

  test('late evening rolls back into night', () {
    expect(defaultRunTitle(at(22)), 'Night run');
    expect(defaultRunTitle(at(23)), 'Night run');
  });

  test('every hour of the day produces a name', () {
    for (var hour = 0; hour < 24; hour++) {
      expect(defaultRunTitle(at(hour)), isNotEmpty, reason: 'hour $hour');
    }
  });
}
