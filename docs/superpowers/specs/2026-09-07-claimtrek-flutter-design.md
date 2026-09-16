# ClaimTrek Flutter — Design

**Date:** 2026-09-07
**Status:** Approved; implementation begun
**Revised:** 2026-09-07 — geometry engine changed from `dart_jts` to `clipper2`. See §5.
**Target:** `G:\Projects\MobSys\flutter`

---

## 1. Context and purpose

ClaimTrek is a GPS territory-capture running app. Run a closed loop, claim the ground inside
it; rivals take it back by running over it. A second mode finds and follows nearby hiking
trails.

The app is intended to be kept: portfolio-grade, properly tested, potentially shipped.

## 2. Scope

**v1 is local-only.**

In scope:

- Territory capture: GPS tracking, loop closure detection, polygon construction and repair,
  claim resolution and stealing, area accounting
- Map with OSM tiles and territory overlay
- Leaderboard
- Run summary with commit-on-save semantics
- Trek mode: Overpass trail search, trail list, trail detail
- Elevation chart and waypoint arrow
- Sensors: GPS, accelerometer (anti-cheat cadence), compass, step counter, barometer, haptics
- Local persistence with seeded rivals
- GPX replay source for indoor testing

Out of scope for v1:

- Firebase / Firestore and real multiplayer
- OpenRouteService elevation profiles
- Thunderforest tiles (key required; falls back to OSM Mapnik)

## 3. Approach

`geo/` and `sensor/` are pure Dart with no Flutter imports. That is a genuine design property
and it is preserved mechanically, by a test rather than by discipline.

Domain types are plain immutable classes, navigation is routes, and a track is a
`List<LatLng>`.

### Library choices

| Choice | Note |
|---|---|
| `clipper2` + hand-written WKT | geometry; see §5, `dart_jts` was tried and rejected |
| Drift | persistence; `watch()` streams straight into the UI |
| `flutter_map` | OSM tiles; User-Agent required |
| `PolygonLayer` + `PolylineLayer` + hatch painter | territories, live trace, unverified fill |
| `CustomPainter` | elevation chart and waypoint arrow — genuinely custom |
| `ListView.builder` | lists |
| `geolocator` | GPS; includes the foreground service |
| `sensors_plus` + `pedometer` | sensors, behind an availability probe |
| `dio` + `json_serializable` | Overpass |
| `go_router` + Riverpod | navigation and state |

### Rejected alternatives

- **Melos monorepo** (`packages/claimtrek_geo` etc). Maximum isolation, but the bootstrap,
  versioning and IDE overhead is not repaid with a single consumer. Revisit if the geometry
  library gains a second one.

## 4. Module layout

```
flutter/
├── lib/
│   ├── main.dart, app.dart          routes, theme
│   ├── geo/            PURE DART — no flutter/ or dart:ui imports
│   │   ├── lat_lng.dart
│   │   ├── projection.dart
│   │   ├── loop_detector.dart
│   │   ├── territory_engine.dart
│   │   └── wkt.dart                 WKT read/write for PathsD
│   ├── sensor/         PURE DART — no flutter/ or dart:ui imports
│   │   ├── cadence_analyzer.dart
│   │   └── barometer.dart
│   ├── location/
│   │   ├── location_source.dart     abstract + Fix + accept()
│   │   ├── fused_source.dart
│   │   ├── replay_source.dart
│   │   └── tracking_controller.dart
│   ├── data/
│   │   ├── local/                   Drift database, tables, DAOs, path codec
│   │   ├── remote/                  Overpass client and DTOs
│   │   ├── model/                   immutable domain models
│   │   ├── territory_repository.dart
│   │   ├── trail_repository.dart
│   │   └── player_identity.dart
│   └── ui/
│       ├── home/                    leaderboard + treks tabs
│       ├── tracking/
│       ├── summary/
│       ├── trail/
│       └── painters/
└── test/
    ├── geo/, sensor/, data/, widget/
    └── architecture/purity_test.dart
```

### Enforced boundary

A test fails the build if anything under `lib/geo/` or `lib/sensor/` imports `package:flutter`
or `dart:ui`. It costs roughly fifteen lines to make mechanical. That property is what lets the
core suite run in milliseconds with no emulator, and it is the first thing to rot silently.

`geo/wkt.dart` holds serialisation only — reading and writing `PathsD` as WKT, plus the
containment analysis that decides which rings are holes. It is deliberately separate from
`territory_engine.dart` so the storage format can change without touching the algorithm, and
so it can be tested against hand-written WKT strings rather than only through round trips.

## 5. Geometry core

Constants:

| Constant | Value |
|---|---|
| `MIN_POINTS` | 20 |
| `MIN_TRAVEL_M` | 200.0 |
| `CLOSE_RADIUS_M` | 30.0 |
| `SLIVER_AREA_M2` | 50.0 |
| `METRES_PER_DEGREE_LAT` | 111320.0 |
| `EARTH_RADIUS_M` | 6371008.8 |
| closure-progress falloff | 300 m |
| `MAX_ACCURACY_M` | 20 |
| `MAX_SPEED_MS` | 8 |
| `VERIFIED_THRESHOLD` | 0.8 |
| `MIN_STD_DEV` (cadence) | 0.35 |
| `MIN_GAIN_STEP_M` (barometer) | 0.6 |

Two design decisions:

- **All geometry happens in a local planar metre projection, never in degrees.** Projected once
  per run about the first fix, so area reads directly as square metres.
- **Territories are stored in geographic WKT, not metres.** Two runs projected about their own
  reference points shear against each other; everything converts into one shared metre frame at
  the moment of a boolean operation. `refLat`/`refLng` are still stored per row.

### Engine: why not `dart_jts` — resolved 2026-09-07

The design originally specified `dart_jts` as a 1:1 JTS port. **It cannot do the job.** Every
overlay operation is an unimplemented stub that throws `UnimplementedError: Not implemented
yet` — `difference`, `union`, `unionGeom`, `intersection`, `symDifference`. Only `buffer`, the
predicates, the measurements and the WKT reader/writer are real.

The original verification was inadequate and this is worth recording: it grepped for method
*signatures* and found all of them present. A signature is not an implementation. Nothing was
executed until the tests ran.

The failure was also nearly invisible. `resolveClaim` wrapped its boolean op in a catch-all
that treated any error as "this territory is unaffected", so a stubbed `difference` presented
as *stealing silently doing nothing* rather than as a crash. Catch-alls around a load-bearing
operation are now avoided: a clip that fails keeps the defender's ground, but only failures
that can actually occur are caught.

**`clipper2` 0.0.3** replaces it — a pure-Dart port of Angus Johnson's Clipper2, no stubs, no
Flutter dependency. Verified by execution against the reference fixtures before adoption:
difference 5000.0, union 15000.0, intersect 5000.0, sliver 20.0, holed polygon 7500.0 across
two paths. Exact, no floating-point drift.

Consequences:

- A territory is a `PathsD` — a flat list of rings, shells positively signed and holes
  negatively, so `paths.area` is correct with no bookkeeping. Holes are real: carving a rival's
  claim out of the middle of your ground produces one.
- Self-intersection repair is a `nonZero`-fill-rule union rather than `buffer(0)`. A
  figure-of-eight comes back as exactly two lobes.
- **WKT is hand-written** (`lib/geo/wkt.dart`), since dropping `dart_jts` drops its reader and
  writer. Shell/hole grouping is by containment depth, deliberately *not* clipper's own
  `booleanOpPolyTreeD`: that hardcodes `ClipperD()` at two decimal places, and territories are
  written in degrees where 0.01° is about a kilometre. There is a regression test for it.
- `null` from `readWkt` means "could not parse"; empty means "parsed, no geometry". Truncated
  WKT must never read as an empty territory — that silently deletes someone's ground.
- `Projection.project` returns clipper's `PointD` rather than a wrapper type, avoiding a
  conversion on every vertex of every ring.

### Verification strategy

Geometry tests are written **first, before any app code**, as goldens over real measured
quantities: 10 000 m² for a 100 m square, 5 000 m² left after a 50 m-shifted overlap,
15 000 m² for a merged pair, a sliver below the 50 m² floor dropped entirely.

The assertion is not "produces a polygon" but "produces the right polygon". That is precisely
what caught the `dart_jts` problem, on the first run, with no screens built.

TDD throughout `geo/` and `sensor/`: tests first, no exceptions.

## 6. Data layer

Drift tables, including indices:

- `territories` — id, ownerId, ownerName, colorHex, wkt, areaM2, geohash5, refLat, refLng,
  claimedAt, verified. Indices on `geohash5` and `ownerId`.
- `runs` — id, title, isPublic, startedAt, durationMs, distanceM, steps, elevationGainM,
  areaM2, verified, plausibleRatio, refLat, refLng, encodedPath.
- `trails` — id, name, kind, lengthM, encodedPath, geohash5, cachedAt. Index on `geohash5`.

`encodedPath` keeps the `"lat,lng;lat,lng;..."` single-column encoding — a few hundred points
do not warrant a join table. `PathCodec` handles the encoding.

Repositories expose Drift `watch()` streams. The write-through shape a backend would use is
retained. Rivals are seeded around the first run's origin.

## 7. Location and sensors

### Foreground service

`flutter_foreground_task` runs its callback in a separate Dart isolate with no shared memory,
requiring a `SendPort` bridge.

**Decision: use `geolocator`'s `AndroidSettings.foregroundNotificationConfig` instead.** It
stands up a `location`-type foreground service and continues delivering fixes to the main
isolate. One dependency rather than two, no isolate bridge, and the same guarantee that
matters: Android does not throttle updates when the screen sleeps, so polygons do not come out
as triangles. The exact API is to be confirmed against the installed `geolocator` version
before it is relied upon.

Location request configuration: high accuracy, 3 m minimum displacement.

### Sensor availability

Dart streams for an absent sensor do not error — they simply never emit, which is
indistinguishable from present-but-idle.

**Decision: an explicit availability probe.** Subscribe, await the first event with a short
timeout, hide the feature on timeout. The rule is unchanged — a missing sensor hides its
feature entirely, never a greyed-out control or a "not supported" message — but the mechanism
differs and must be implemented as such.

Sensor roles and the mechanism chosen for each:

| Role | Mechanism |
|---|---|
| Polygon | `geolocator` |
| Anti-cheat cadence | `sensors_plus` accelerometer stream |
| Compass needle, waypoint arrow | `flutter_compass` (0.8.1) |
| Step totals | `pedometer`, `ACTIVITY_RECOGNITION` permission |
| Elevation gain | `sensors_plus` barometer, see open item 2 |
| Loop-closure haptic | `HapticFeedback` from `flutter/services` — no package |

`flutter_compass` is preferred over deriving heading from raw `sensors_plus` accelerometer and
magnetometer streams: the sensor fusion and low-pass filtering it provides would otherwise have
to be hand-rolled, and a jittery needle is a visible defect. Haptics need no package — Flutter's built-in `HapticFeedback` covers the single
pulse on loop closure, so `vibration` is not a dependency.

### Location source

`LocationSource` with `Fix(point, accuracyM, speedMs, altitudeM, timestampMs)` and the
`accept()` gate. `FusedSource` uses `geolocator`; `ReplaySource` plays a bundled
GPX at 10×, bound to a long-press on the start control. Indoor replay is what makes the
geometry debuggable at all and is not optional.

### Anti-cheat

`CadenceAnalyzer` is pure maths over a ring buffer with mean-removed upward zero-crossings and
hysteresis, covered by synthetic-waveform tests. `PlausibilityTracker` and its
below-80%-marks-unverified behaviour: such runs are
saved, drawn hatched, and excluded from the leaderboard, never rejected outright.

## 8. UI

`go_router` routes replace the four Activities. Riverpod for state.

`flutter_map` with OSM Mapnik tiles provides pan and zoom, so territories become a
`PolygonLayer` and the live trace a `PolylineLayer`. Only the hatched unverified fill needs a
custom painter layer above them.

The elevation chart and waypoint arrow are real `CustomPainter`s. The
no-allocation-in-`paint` rule is retained: paints and paths are built once, not per frame.

Claims commit on **Save**, not on **Stop** — the summary screen is the commit point, so Discard
is a real choice that leaves the world untouched. The tracking screen only previews.

Two traps, both already paid for:

- **Overpass answers HTTP 406 to default HTTP-client User-Agents.** A real User-Agent is
  required. Queries are cached and debounced; the public instance rate-limits.
- **`fitCamera` has a before-layout trap.** It must run from
  `onMapReady`, not `initState`, or it lands on zoom 0 and renders the whole world.

## 9. Error handling

Explicit, designed states for: location permission denied; permission permanently denied;
location services disabled; no fix acquired yet; offline; Overpass rate-limited or 406; missing
sensor; empty leaderboard; loop never closed.

## 10. Testing

- **Pure unit** — `geo/` and `sensor/`: the geometry and cadence suites plus the import-purity
  guard. No Flutter binding, milliseconds to run.
- **Repository** — against an in-memory Drift database (`NativeDatabase.memory()`), which
  needs no extra setup on Windows.
- **Widget** — per screen.
- **Not in v1** — emulator-dependent integration tests. `ReplaySource` covers that ground far
  more cheaply and deterministically.

## 11. Toolchain and dependencies

Flutter is upgraded to current stable before scaffolding. The installed 3.32.8 / Dart 3.8.1
(July 2025) cannot resolve current versions of several required packages — `flutter_riverpod`
3.4.3 and `flutter_foreground_task` 11.0.3 both require Dart `^3.12` — and pub would silently
select older ones.

Verified available on pub.dev as of 2026-09-07. This table is the set whose availability was
checked against the risky parts of the design; it is not the complete `pubspec.yaml`, and
build-time-only packages (`drift_dev`, `build_runner`, `json_serializable`) are omitted:

| Package | Latest | Role |
|---|---|---|
| `clipper2` | 0.0.3 | geometry (booleans, areas) |
| `flutter_map` | 8.3.2 | tiles and vector layers |
| `latlong2` | 0.10.1 | flutter_map coordinate type |
| `geolocator` | 14.0.3 | GPS + foreground service |
| `sensors_plus` | 7.1.0 | accelerometer, magnetometer, barometer |
| `pedometer` | 4.2.0 | step counter |
| `flutter_compass` | 0.8.1 | heading for needle and waypoint arrow |
| `drift` | 2.34.4 | persistence |
| `flutter_riverpod` | 3.4.3 | state |
| `dio` | resolved at scaffold | Overpass HTTP |
| `go_router` | resolved at scaffold | routing |

Exact versions are resolved against the upgraded SDK at scaffolding time. Every dependency must
be justifiable; none is added without a stated reason.

### Web target

Drift on web needs `sqlite3.wasm` and `drift_worker.js` in `web/`, version-matched to the
resolved `sqlite3` and `drift` packages (3.5.2 and 2.34.4). They are committed rather than
fetched at build time, so the build does not depend on GitHub being reachable.

`driftDatabase()` also **throws synchronously on web** unless its `web:` parameter is supplied
with URIs for those two files; the parameter is ignored on native, so omitting it compiles and
passes every native test while failing only in a browser. `ClaimTrekDatabase` always passes it.

Because that failure happened inside an unawaited bootstrap future, it first presented as the
UI sitting on "Loading…" forever with nothing logged. Bootstrap now catches and surfaces the
error instead: broken and loud beats broken and silent.

## 12. Open items to confirm at implementation

1. `geolocator`'s `foregroundNotificationConfig` API on the installed version.
2. `sensors_plus` 7.x barometer stream availability; fall back to `environment_sensors`.

Resolved 2026-09-07: the two `dart_jts` items (polygon construction, `applyCF` mutation
semantics) are moot — the library was replaced. See §5. Its transform machinery was in fact
sound; the overlay operations were not.

## 13. Build order

Progress as of 2026-09-07: steps 1–4 complete, 5 and 6 partly done. 77 tests passing,
analyzer clean.

1. ✅ Scaffold, upgrade toolchain, dependency resolution, purity guard test
2. ✅ `geo/` — tests first, then implementation, then cross-implementation goldens
3. ✅ `sensor/` — tests first, then implementation
4. ✅ `data/` — Drift schema, DAOs, repositories, in-memory tests. Rivals now come from
   storage rather than memory, and claims are committed through `TerritoryRepository`
5. 🟡 `location/` — `LocationSource`, `ReplaySource` and the GPX fixture done;
   `FusedSource` and the foreground config outstanding
6. 🟡 Tracking screen and map, driven by `ReplaySource` — map, territory and hole rendering,
   live trace, claim/steal resolution and persistence done; unverified ground is drawn faded
   rather than hatched, and there is no pan-to-fit yet
7. Summary and commit-on-save
8. Leaderboard
9. Trek mode: Overpass, trail list, trail detail, waypoint arrow
10. Elevation chart
11. Error states and polish

Cut order if behind: trek mode first, then elevation chart.
Territory capture alone is the app.
