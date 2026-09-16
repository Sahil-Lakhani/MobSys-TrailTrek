import 'package:geolocator/geolocator.dart';

/// Every way asking for location can end.
///
/// Modelled as one closed set rather than a pair of booleans because each state needs a
/// different thing offered to the user, and a screen that collapses them shows the wrong
/// button: "try again" is useless once the user has chosen "don't ask again", and sending
/// someone to app settings is wrong when the problem is that the phone's location switch is off.
enum LocationAccess {
  /// Not asked yet. The map opens here on a first launch.
  notRequested,

  /// The system dialogue is on screen.
  requesting,

  granted,

  /// Refused this time. Asking again is allowed and worth offering.
  denied,

  /// Refused permanently, or blocked by policy. Only app settings can change it.
  deniedForever,

  /// Granted, but the device's location switch is off. App settings will not help; the
  /// location settings screen will.
  servicesDisabled,
}

/// Thin wrapper over `geolocator`'s permission calls.
///
/// Exists so the controller depends on this small enum rather than on the plugin's own types,
/// and so the whole permission flow can be exercised in a widget test with a fake.
class LocationAccessGate {
  const LocationAccessGate();

  /// What the situation is right now, without prompting.
  Future<LocationAccess> check() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.servicesDisabled;
    }
    return _map(await Geolocator.checkPermission());
  }

  /// Prompts if that is still possible.
  ///
  /// Services are re-checked afterwards as well as before: the user can walk out to the system
  /// location toggle from the permission dialogue and come back with a different answer than
  /// the one we started with.
  Future<LocationAccess> request() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.servicesDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final mapped = _map(permission);
    if (mapped == LocationAccess.granted &&
        !await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.servicesDisabled;
    }
    return mapped;
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// `unableToDetermine` is treated as "not asked yet" rather than as a refusal: it is what a
  /// platform returns when it has no answer, and offering the prompt is the recoverable read.
  static LocationAccess _map(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.denied => LocationAccess.denied,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.unableToDetermine => LocationAccess.notRequested,
      };
}
