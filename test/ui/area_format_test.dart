import 'package:claimtrek/ui/common/area_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('areas read in square kilometres', () {
    expect(formatArea(2500000), '2.50 km²');
    expect(formatArea(12340000), '12.3 km²');
  });

  test('a typical loop is a few hundredths, shown to three places', () {
    // The figure-eight fixture encloses 62 500 m².
    expect(formatArea(62500), '0.063 km²');
    expect(formatArea(1000), '0.001 km²');
  });

  test('a tiny claim keeps a fourth place rather than reading as zero', () {
    expect(formatArea(400), '0.0004 km²');
  });

  test('nothing is zero', () {
    expect(formatArea(0), '0 km²');
  });

  test('the bare number is available for layouts that style the unit apart', () {
    expect(formatAreaKm2Value(62500), '0.063');
  });
}
