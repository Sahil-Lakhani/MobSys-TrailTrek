import 'package:geolocator/geolocator.dart';

enum LocationAccess {
  notRequested,

  requesting,

  granted,

  denied,

  deniedForever,

  servicesDisabled,
}

class LocationAccessGate {
  const LocationAccessGate();

  Future<LocationAccess> check() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.servicesDisabled;
    }
    return _map(await Geolocator.checkPermission());
  }

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

  static LocationAccess _map(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.denied => LocationAccess.denied,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.unableToDetermine => LocationAccess.notRequested,
      };
}
