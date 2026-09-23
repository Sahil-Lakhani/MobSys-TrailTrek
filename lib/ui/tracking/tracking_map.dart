import 'package:clipper2/clipper2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../geo/lat_lng.dart' as geo;
import '../../geo/territory_engine.dart';
import '../../geo/wkt.dart';
import '../../location/location_access.dart';
import 'location_access_notice.dart';
import 'tracking_controller.dart';

/// OpenStreetMap's land colour, used behind the tiles.
///
/// Deliberately not themed: the tiles themselves are always light, so matching the app's dark
/// theme here would make the gaps more obvious rather than less.
const Color osmLand = Color(0xFFF2EFE9);

ll.LatLng toMap(geo.LatLng p) => ll.LatLng(p.latitude, p.longitude);

/// Geographic ring vertices are (x = longitude, y = latitude).
List<ll.LatLng> _ringToMap(PathD ring) =>
    ring.map((p) => ll.LatLng(p.y, p.x)).toList();

/// "#RRGGBB" as stored per owner. Falls back rather than throwing: a bad colour should not
/// cost the territory its place on the map.
Color parseHex(String hex, Color fallback) {
  final cleaned = hex.replaceFirst('#', '').trim();
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  return value == null ? fallback : Color(0xFF000000 | value);
}

/// Turn a territory's rings into map polygons, honouring holes — which are not hypothetical:
/// carving a rival out of the middle of your ground produces one.
List<Polygon> territoryPolygons(
  PathsD geometry, {
  required Color fill,
  required Color border,
  double borderWidth = 2,
}) => groupIntoPolygons(geometry).map((rings) {
  return Polygon(
    points: _ringToMap(rings.first),
    holePointsList: rings.length > 1
        ? rings.skip(1).map(_ringToMap).toList()
        : null,
    color: fill,
    borderColor: border,
    borderStrokeWidth: borderWidth,
  );
}).toList();

/// The map, its overlays, and the states that stand in for them when location is unavailable.
///
/// Deliberately not a `Scaffold`: the home screen owns the scaffold so the leaderboard sheet
/// and the start control can sit above this in one stack.
class TrackingMap extends ConsumerStatefulWidget {
  const TrackingMap({super.key});

  @override
  ConsumerState<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends ConsumerState<TrackingMap>
    with TickerProviderStateMixin {
  final MapController _map = MapController();
  bool _ready = false;
  bool _centred = false;

  /// Parsed territory geometry, kept between builds.
  ///
  /// `build` runs on every fix, and re-parsing every WKT each time is string parsing on the UI
  /// thread several times a second. Keyed by id and invalidated on the WKT itself, so ground
  /// that changes hands still redraws.
  final Map<String, ({String wkt, PathsD geometry})> _geometry = {};

  /// Follows the runner while recording, and gives up the moment they pan the map themselves —
  /// dragging the view back out from under a gesture is worse than not following at all.
  bool _following = true;
  late final AnimationController _camera = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  ll.LatLng? _cameraFrom;
  ll.LatLng? _cameraTo;

  /// Fades a freshly closed claim in, so the ground reads as being taken rather than blinking
  /// into existence.
  late final AnimationController _claimReveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  bool _claimShowing = false;

  @override
  void initState() {
    super.initState();
    _camera.addListener(_stepCamera);
    _claimReveal.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _camera.dispose();
    _claimReveal.dispose();
    super.dispose();
  }

  void _stepCamera() {
    final from = _cameraFrom;
    final to = _cameraTo;
    if (from == null || to == null || !_ready) return;
    final t = Curves.easeOutCubic.transform(_camera.value);
    _map.move(
      ll.LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      ),
      _map.camera.zoom,
    );
  }

  /// Eases the camera onto [target] rather than cutting to it.
  void _followTo(ll.LatLng target) {
    if (!_ready || !_following || _camera.isAnimating) return;
    final current = _map.camera.center;
    // Under a metre the move is invisible and only costs frames.
    if ((current.latitude - target.latitude).abs() < 1e-6 &&
        (current.longitude - target.longitude).abs() < 1e-6) {
      return;
    }
    _cameraFrom = current;
    _cameraTo = target;
    _camera.forward(from: 0);
  }

  /// Centring must wait for `onMapReady`. Run from `initState` it lands on zoom 0 and renders
  /// the whole world, because the map has no size to fit against yet.
  void _centreOnce(geo.LatLng? origin) {
    if (!_ready || _centred || origin == null) return;
    _centred = true;
    _map.move(toMap(origin), 15.2);
  }

  PathsD _geometryOf(String id, String wkt) {
    final cached = _geometry[id];
    if (cached != null && cached.wkt == wkt) return cached.geometry;
    final parsed = TerritoryEngine.fromWkt(wkt) ?? const <PathD>[];
    _geometry[id] = (wkt: wkt, geometry: parsed);
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingControllerProvider);

    // Only while there is still something to centre. Registering a callback on every build
    // costs a frame of work forever, for something that happens once.
    if (!_centred) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _centreOnce(state.origin),
      );
    }

    // A claim appearing is the moment the run pays off; give it a moment of its own.
    final hasClaim = state.claim != null;
    if (hasClaim != _claimShowing) {
      _claimShowing = hasClaim;
      if (hasClaim) {
        _claimReveal.forward(from: 0);
      } else {
        _claimReveal.value = 0;
      }
    }

    final polygons = <Polygon>[];

    // Territories that have gone are dropped, or the cache grows for the life of the screen.
    if (_geometry.length > state.territories.length) {
      final live = {for (final t in state.territories) t.id};
      _geometry.removeWhere((id, _) => !live.contains(id));
    }

    for (final territory in state.territories) {
      final owned = territory.ownerId == state.playerId;
      final base = parseHex(
        territory.colorHex,
        owned ? Colors.blue : Colors.red,
      );
      polygons.addAll(
        territoryPolygons(
          _geometryOf(territory.id, territory.wkt),
          // Unverified ground is held and drawn, but faded — it does not score.
          fill: base.withValues(alpha: territory.verified ? 0.38 : 0.15),
          border: base,
          borderWidth: territory.verified ? 2 : 1,
        ),
      );
    }

    // The live preview, drawn only in the moment between closing and committing.
    if (state.claim != null) {
      final reveal = Curves.easeOut.transform(_claimReveal.value);
      polygons.addAll(
        territoryPolygons(
          state.claim!,
          fill: Colors.blue.withValues(alpha: 0.40 * reveal),
          border: Colors.blue.shade700.withValues(alpha: reveal),
        ),
      );
    }

    final fix = state.currentFix;

    // Keep the runner on screen while recording.
    if (state.running && fix != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _followTo(toMap(fix.point)),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            // Tiles arrive a moment after the map does, and flutter_map paints the gap
            // in its default grey — a hard block that reads as a rendering fault. This
            // is OpenStreetMap's own land tone, so a tile still loading is a shade of
            // the map rather than a hole in it.
            backgroundColor: osmLand,
            initialCenter: toMap(state.origin ?? fallbackOrigin),
            initialZoom: 15.2,
            onMapReady: () {
              _ready = true;
              _centreOnce(ref.read(trackingControllerProvider).origin);
            },
            onPositionChanged: (position, hasGesture) {
              // The runner moved the map themselves; stop pulling it back under them.
              if (hasGesture && _following) {
                setState(() => _following = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // OSM rejects default agents outright — the same policy that answers
              // Overpass requests with a 406.
              userAgentPackageName: 'de.hsm.claimtrek',
            ),
            PolygonLayer(polygons: polygons),

            // How good the fix is, drawn to scale. "Is my location correct" should be
            // something the runner can see rather than take on trust.
            if (fix != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: toMap(fix.point),
                    radius: fix.accuracyM,
                    useRadiusInMeter: true,
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderColor: Colors.blue.withValues(alpha: 0.45),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),

            if (state.track.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: state.track.map(toMap).toList(),
                    color: Colors.amber.shade600,
                    strokeWidth: 4,
                  ),
                ],
              ),

            if (fix != null || state.track.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: toMap(fix?.point ?? state.track.last),
                    width: 26,
                    height: 26,
                    child: _YouMarker(headingDeg: state.headingDeg),
                  ),
                ],
              ),
          ],
        ),
        // While running, the live counter on the home screen is the single stats surface.
        if (!state.running) SafeArea(child: _StatusPanel(state: state)),
        if (state.access != LocationAccess.granted)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: LocationAccessNotice(access: state.access),
            ),
          ),
      ],
    );
  }
}

/// Where you are, pointing where you face when there is a compass to say so.
class _YouMarker extends StatelessWidget {
  const _YouMarker({required this.headingDeg});

  final double? headingDeg;

  @override
  Widget build(BuildContext context) {
    const dot = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.amber,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: Colors.black87, width: 2),
        ),
      ),
    );

    // No compass, no needle. A needle that does not turn is worse than none.
    if (headingDeg == null) return const Padding(padding: EdgeInsets.all(4), child: dot);

    return Transform.rotate(
      angle: headingDeg! * 3.1415926535897932 / 180.0,
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Icon(Icons.navigation, size: 14, color: Colors.black87),
          ),
          Padding(padding: EdgeInsets.all(6), child: dot),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.state});

  final TrackingState state;

  static String _area(double m2) => m2 >= 10000
      ? '${(m2 / 10000).toStringAsFixed(2)} ha'
      : '${m2.round()} m²';

  @override
  Widget build(BuildContext context) {
    final fix = state.currentFix;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.status, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _Stat(label: 'Distance', value: '${state.distanceM.round()} m'),
                _Stat(
                  label: 'Closure',
                  value: '${(state.closureProgress * 100).round()}%',
                ),
                _Stat(label: 'Plots', value: '${state.territories.length}'),

                // Only shown when there is a receiver actually reporting one.
                if (fix != null)
                  _Stat(label: 'GPS', value: '±${fix.accuracyM.round()} m'),

                // Each of these appears only if the device has the sensor behind it.
                if (state.availability.pedometer)
                  _Stat(label: 'Steps', value: '${state.steps}'),
                if (state.availability.barometer)
                  _Stat(
                    label: 'Climb',
                    value: '${state.elevationGainM.round()} m',
                  ),

                if (state.closed) ...[
                  _Stat(label: 'Claimed', value: _area(state.claimedAreaM2)),
                  _Stat(
                    label: 'Stolen',
                    value: state.stolenAreaM2 <= 0
                        ? '—'
                        : '${_area(state.stolenAreaM2)} '
                              'from ${state.stolenFromCount}',
                  ),
                ],
              ],
            ),
            if (state.closed && !state.verified)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Unverified — excluded from the leaderboard',
                  style: TextStyle(color: Colors.deepOrange),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
