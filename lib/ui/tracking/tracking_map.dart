import 'package:clipper2/clipper2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../geo/lat_lng.dart' as geo;
import '../../geo/territory_engine.dart';
import '../../geo/wkt.dart';
import '../common/glass_panel.dart';
import '../common/stat_tile.dart';
import '../theme/app_colors.dart';
import 'tracking_controller.dart';

const Color osmLand = Color(0xFFF2EFE9);

ll.LatLng toMap(geo.LatLng p) => ll.LatLng(p.latitude, p.longitude);

List<ll.LatLng> _ringToMap(PathD ring) =>
    ring.map((p) => ll.LatLng(p.y, p.x)).toList();

Color parseHex(String hex, Color fallback) {
  final cleaned = hex.replaceFirst('#', '').trim();
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  return value == null ? fallback : Color(0xFF000000 | value);
}

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

class TrackingMap extends ConsumerStatefulWidget {
  const TrackingMap({super.key});

  @override
  ConsumerState<TrackingMap> createState() => TrackingMapState();
}

class TrackingMapState extends ConsumerState<TrackingMap>
    with TickerProviderStateMixin {
  final MapController _map = MapController();
  bool _ready = false;
  bool _centred = false;

  final Map<String, ({String wkt, PathsD geometry})> _geometry = {};

  bool _following = true;
  late final AnimationController _camera = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  ll.LatLng? _cameraFrom;
  ll.LatLng? _cameraTo;

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

  void _followTo(ll.LatLng target) {
    if (!_ready || !_following || _camera.isAnimating) return;
    final current = _map.camera.center;
    if ((current.latitude - target.latitude).abs() < 1e-6 &&
        (current.longitude - target.longitude).abs() < 1e-6) {
      return;
    }
    _cameraFrom = current;
    _cameraTo = target;
    _camera.forward(from: 0);
  }

  void recentre() {
    if (!_ready) return;
    final state = ref.read(trackingControllerProvider);
    final target =
        state.currentFix?.point ??
        (state.track.isNotEmpty ? state.track.last : state.origin);
    if (target == null) return;
    setState(() => _following = true);
    _camera.stop();
    _cameraFrom = _map.camera.center;
    _cameraTo = toMap(target);
    _camera.forward(from: 0);
  }

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

    if (!_centred) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _centreOnce(state.origin),
      );
    }

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
          fill: base.withValues(alpha: territory.verified ? 0.38 : 0.15),
          border: base,
          borderWidth: territory.verified ? 2 : 1,
        ),
      );
    }

    if (state.claim != null) {
      final reveal = Curves.easeOut.transform(_claimReveal.value);
      polygons.addAll(
        territoryPolygons(
          state.claim!,
          fill: AppColors.accent.withValues(alpha: 0.45 * reveal),
          border: AppColors.bg.withValues(alpha: reveal),
          borderWidth: 2.5,
        ),
      );
    }

    final fix = state.currentFix;

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
            backgroundColor: osmLand,
            initialCenter: toMap(state.origin ?? fallbackOrigin),
            initialZoom: 15.2,
            onMapReady: () {
              _ready = true;
              _centreOnce(ref.read(trackingControllerProvider).origin);
            },
            onPositionChanged: (position, hasGesture) {
              if (hasGesture && _following) {
                setState(() => _following = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'de.hsm.claimtrek',
            ),
            PolygonLayer(polygons: polygons),

            if (fix != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: toMap(fix.point),
                    radius: fix.accuracyM,
                    useRadiusInMeter: true,
                    color: AppColors.bg.withValues(alpha: 0.12),
                    borderColor: AppColors.bg.withValues(alpha: 0.55),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

            if (state.track.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: state.track.map(toMap).toList(),
                    color: AppColors.accent,
                    strokeWidth: 5,
                    borderColor: AppColors.bg,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),

            if (fix != null || state.track.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: toMap(fix?.point ?? state.track.last),
                    width: 44,
                    height: 44,
                    child: _YouMarker(headingDeg: state.headingDeg),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _YouMarker extends StatefulWidget {
  const _YouMarker({required this.headingDeg});

  final double? headingDeg;

  @override
  State<_YouMarker> createState() => _YouMarkerState();
}

class _YouMarkerState extends State<_YouMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _halo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = widget.headingDeg;

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _halo,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_halo.value);
            return Container(
              width: 18 + 26 * t,
              height: 18 + 26 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.45 * (1 - t)),
              ),
            );
          },
        ),
        if (heading != null)
          Transform.rotate(
            angle: heading * 3.1415926535897932 / 180.0,
            child: const SizedBox.square(
              dimension: 40,
              child: Align(
                alignment: Alignment.topCenter,
                child: Icon(
                  Icons.navigation_rounded,
                  size: 16,
                  color: AppColors.bg,
                ),
              ),
            ),
          ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.bg, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 6),
            ],
          ),
        ),
      ],
    );
  }
}

class MapStatusStrip extends StatelessWidget {
  const MapStatusStrip({required this.state, super.key});

  final TrackingState state;

  static String _area(double m2) => m2 >= 10000
      ? '${(m2 / 10000).toStringAsFixed(2)} ha'
      : '${m2.round()} m²';

  @override
  Widget build(BuildContext context) {
    final fix = state.currentFix;

    final stats = <Widget>[
      if (state.closed) ...[
        StatTile(
          label: 'Claimed',
          value: _area(state.claimedAreaM2),
          valueColor: AppColors.accent,
        ),
        StatTile(
          label: 'Stolen',
          value: state.stolenAreaM2 <= 0 ? '—' : _area(state.stolenAreaM2),
        ),
      ],
      StatTile(label: 'Plots', value: '${state.territories.length}'),
      if (state.distanceM > 0)
        StatTile(label: 'Distance', value: '${state.distanceM.round()} m'),

      if (fix != null)
        StatTile(label: 'GPS', value: '±${fix.accuracyM.round()} m'),

      if (state.availability.pedometer && state.steps > 0)
        StatTile(label: 'Steps', value: '${state.steps}'),
      if (state.availability.barometer && state.elevationGainM > 0)
        StatTile(label: 'Climb', value: '${state.elevationGainM.round()} m'),
    ];

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fix != null ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: AppColors.outline,
                    ),
                  stats[i],
                ],
              ],
            ),
          ),
          if (state.closed && !state.verified)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Pill.warning(
                label: 'Unverified — excluded from the leaderboard',
              ),
            ),
        ],
      ),
    );
  }
}
