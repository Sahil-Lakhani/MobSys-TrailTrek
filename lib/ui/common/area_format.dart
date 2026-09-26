/// Square kilometres from square metres.
double areaKm2(double m2) => m2 / 1e6;

/// The number part of an area in km², without the unit — for layouts that set the unit apart.
///
/// Claims are small next to a square kilometre (a loop round a park is a few hundredths), so
/// the decimals grow as the number shrinks: enough to tell two claims apart, never a wall of
/// zeros.
String formatAreaKm2Value(double m2) {
  final km2 = areaKm2(m2);
  if (km2 <= 0) return '0';
  if (km2 >= 10) return km2.toStringAsFixed(1);
  if (km2 >= 1) return km2.toStringAsFixed(2);
  if (km2 >= 0.001) return km2.toStringAsFixed(3);
  return km2.toStringAsFixed(4);
}

/// Every area in the app, in one unit: `0.063 km²`.
String formatArea(double m2) => '${formatAreaKm2Value(m2)} km²';
