/// A geographic point.
///
/// Deliberately not `latlong2`'s `LatLng` and not a plugin's position type: everything in
/// `geo/` stays unit-testable on a plain Dart VM with no Flutter binding. Conversion to the
/// map library's own type happens at the UI boundary, never in here.
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          other.latitude == latitude &&
          other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}
