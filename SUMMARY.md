# ClaimTrek — handoff

Read this first. It is the working context for anyone picking the project up.

**Location:** `G:\Projects\MobSys\flutter`
**Last updated:** 2026-09-08
**State:** 107 tests passing, analyzer clean, runs on Android and web, nothing committed
(no git repo yet)

---

## 1. The idea

A GPS territory-capture running game.

You go for a run. When your track forms a **closed loop**, you claim the ground inside it. Other
players hold ground too, and running a loop over theirs **takes the overlap from them** — their
plot shrinks, or disappears if you leave them almost nothing. The map is a live picture of who
owns what.

A second mode, **Trek**, finds real hiking trails nearby and helps you follow one.

Two things make it work as a game rather than a drawing app:

- **Area is the score.** Claimed ground is measured in real square metres, so a bigger loop is
  worth more, and stealing is a real transfer — what one player loses, another gains.
- **It has to be hard to cheat.** A phone in a car traces a perfect loop. The app cross-checks
  movement against the accelerometer for a running gait; a run that fails the check is still
  saved and drawn, but marked unverified and left out of the leaderboard.

---

## 2. What exists today

Working end to end, verified in a browser: a map with stored territories, a replayed run that
closes a loop, claims ~10.6 ha, takes ground from an overlapping rival, and persists the result.

```
lib/
  geo/            PURE DART — no flutter/ or dart:ui imports
    lat_lng.dart          immutable geographic point
    projection.dart       lat/lng <-> metres, haversine, bearing, geohash
    loop_detector.dart    closure detection + progress hint
    territory_engine.dart claim building, repair, steal, merge
    wkt.dart              WKT read/write + shell/hole grouping
  sensor/         PURE DART — no flutter/ or dart:ui imports
    cadence_analyzer.dart gait frequency + plausibility + verified tracking
    barometer.dart        pressure -> altitude, elevation gain, smoothing
  device/         plugin-backed sensor adapters, each availability-probed
    sensor_probe.dart     subscribe, await first event, timeout means absent
    device_sensors.dart   accelerometer, barometer, pedometer, compass, haptics
  location/
    location_source.dart  Fix + the accuracy/speed gate
    fused_source.dart     real GPS + the location foreground service
    location_access.dart  the six permission/services states
    replay_source.dart    GPX playback (the indoor test harness)
  data/
    local/                Drift database, tables, DAOs, path codec
    model/models.dart     LeaderboardEntry, ClaimOutcome, ClaimPreview
    player_identity.dart  local opaque player id, name, colour
    territory_repository.dart  claims, leaderboard, runs, rival seeding
    providers.dart        Riverpod wiring
    remote/overpass_client.dart  named hiking routes, 5 km, User-Agent required
    trail_repository.dart        trail cache keyed by geohash cell
  ui/
    app.dart              go_router StatefulShellRoute, 3 tabs
    home/                 map + drag-up leaderboard sheet
    tracking/             map layers, permission notice, controller
    summary/              the commit point: Save or Discard
    runs/                 history list + a past run's path redrawn
    treks/                trail list + detail with the route drawn
assets/demo_loop.gpx      207-point, 1257 m recorded loop that closes
web/sqlite3.wasm, drift_worker.js   required for drift on web
```

### Verified behaviour

| | |
|---|---|
| Loop closure | 20+ fixes, >200 m travelled, back within 30 m of the start |
| Claim | Self-intersecting tracks repaired; a figure-of-eight yields two lobes |
| Steal | Overlap removed from rivals; what they lose equals what the runner takes |
| Sliver rule | A rival left under 50 m² is deleted, not kept as a splinter |
| Merge | A runner's claims fold into one holding — never steals from themselves |
| Holes | A rival carved out of the middle of your ground renders as a real hole |
| Leaderboard | Ranked by area; unverified ground is held and drawn but does not score |
| Persistence | Claims commit to SQLite and reload into identical geometry |
| Save / Discard | A closed loop writes nothing until Save; Discard leaves every rival intact |
| Unclosed runs | A run that never closes is still offered, saved and listed — with no area |
| Run history | Past runs list newest first and redraw their stored path |
| Preview fidelity | The area and steal shown on the summary are the numbers that commit |

---

## 3. Still to build

Roughly in dependency order.

1. **Elevation chart** — a `CustomPainter` fed by the barometer, which now feeds a running
   total but is only shown as a single number.
2. **Polish** — hatched fill for unverified ground (currently just faded), pan-to-fit on the
   map, settings, claim animation, share, deleting a run from history.

Out of scope for now: any backend or real multiplayer, and paid map tiles.

### External services

- **Overpass** (`https://overpass-api.de/api/interpreter`) — free, no key, for trails. It
  answers **HTTP 406 to default HTTP-client User-Agents**; set a real one. Rate-limited, so
  cache and debounce. The `trails` table already exists for that cache.
- **Map tiles** — OpenStreetMap. Same User-Agent requirement.

---

## 4. Key decisions

**All geometry happens in a local planar metre projection, never in degrees.** Projected once
per run about a reference point, so area reads directly as square metres. This is the entire
reason `projection.dart` exists.

**Territories are stored as geographic WKT, not metres.** Two runs projected about their own
reference points shear against each other; everything converts into one shared metre frame at
the moment of a boolean operation. `refLat`/`refLng` are stored per row.

**`geo/` and `sensor/` import no framework code.** `test/architecture/purity_test.dart` fails
the build if they ever do. That property is why the core suite runs in milliseconds with no
device, and it is the first thing to rot silently.

**A territory is a `PathsD`** — a flat list of rings, shells positively signed and holes
negatively, so `paths.area` is correct with no bookkeeping.

**Geometry engine is `clipper2`.** See §5 — this is not a free choice.

**Claims commit on Save, not on Stop.** Closing a loop resolves it through `previewClaim`,
which computes what would be taken without taking it, and parks it as a `PendingRun`. Nothing
reaches storage until the summary screen's Save. That is the only reason Discard can honestly
promise to leave the world untouched — there is nothing to roll back.

### Constants — do not drift from these without reason

| | |
|---|---|
| Minimum fixes for a loop | 20 |
| Minimum travel | 200 m |
| Closure radius | 30 m |
| Sliver floor | 50 m² |
| Metres per degree latitude | 111320 |
| Earth radius | 6371008.8 m |
| Max accepted fix accuracy | 20 m |
| Max accepted speed | 8 m/s |
| Verified threshold | 80% plausible samples |
| Cadence noise floor | 0.35 std dev |
| Elevation gain step floor | 0.6 m |

---

## 5. Traps already hit — do not rediscover these

**`dart_jts` cannot do the geometry.** Every overlay operation is an unimplemented stub that
throws `UnimplementedError` — `difference`, `union`, `unionGeom`, `intersection`,
`symDifference`. The method signatures all exist, which is what makes it look usable. Do not
reintroduce it. `clipper2` is the engine; it was verified by executing real fixtures before
adoption.

**Do not wrap a boolean operation in a catch-all.** That stubbed `difference` first presented
as *stealing silently doing nothing*, because the error was caught and treated as "this
territory is unaffected". Catch only what can actually happen.

**Self-intersection repair is a `nonZero`-fill-rule union**, not a zero-width buffer.

**Do not use clipper's `booleanOpPolyTreeD` on geographic coordinates.** It hardcodes
`ClipperD()` at two decimal places, and 0.01° is about a kilometre. Ring grouping is done by
containment depth instead; there is a regression test for it.

**`readWkt` returns null for "could not parse" and empty for "parsed, no geometry".** Keep that
distinction — truncated WKT reading as an empty territory silently deletes someone's ground.

**`driftDatabase()` throws synchronously on web without its `web:` parameter, and ignores it on
native.** Omitting it compiles, passes every test and passes the analyzer, and fails only in a
browser. `ClaimTrekDatabase` always passes it. The two files it points at must live in `web/`
at versions matching the resolved `sqlite3` and `drift` packages.

**Anti-cheat must abstain when it has no evidence, not convict.** A flat-zero cadence reads as
"moving with no gait at all", i.e. a vehicle. Recording that when no accelerometer is feeding
the analyzer marks *every* run unverified, including on phones that simply lack the sensor. The
controller gates this behind `_cadenceAvailable`; when you wire up real sensors in §3.2, set it
from an availability probe. **A missing sensor hides its feature — it never fails the runner.**

**Sensor availability needs an explicit probe.** Dart streams for an absent sensor do not error,
they simply never emit, which is indistinguishable from present-but-idle. Subscribe, await the
first event with a short timeout, hide the feature on timeout.

**`fitCamera` must run from `onMapReady`,** not `initState`, or it lands on zoom 0 and renders
the whole world.

**`flutter create` regenerates `test/widget_test.dart`.** It references a scaffold app that does
not exist and breaks the suite. Delete it if it reappears.

**Kotlin 2.4's incremental compiler cannot close its caches here.** Every plugin module dies
with `Could not close incremental caches in build\<plugin>\kotlin\...`, and it reproduces from
a deleted `build/`, so it is not stale state. `android/gradle.properties` sets
`kotlin.incremental=false`; leave it. Non-incremental compiles cost a few seconds.

**The Kotlin toolchain cannot be removed, even with no Kotlin source.** The host activity is
Java (`android/app/src/main/java/de/hsm/claimtrek/MainActivity.java`) and the project contains
no `.kt` file, but dropping `id("org.jetbrains.kotlin.android")` from
`android/settings.gradle.kts` makes Flutter fall back to a transitive Kotlin 2.2.10 - below its
own minimum of 2.2.20 - and `dev.flutter.flutter-gradle-plugin` then refuses to apply at all.
The build dies before reaching a single plugin module. Verified by removing it.

**Gradle is configured for 8 GB of heap and 4 GB of metaspace.** With an emulator running, that
is enough to get a build killed for memory. Stop the daemons between builds
(`cd android && ./gradlew --stop`), or lower `org.gradle.jvmargs`.

**`enableWakeLock: true` needs `WAKE_LOCK` in the manifest.** Without it geolocator throws a
`SecurityException` from `obtainWakeLocks` inside `StreamHandlerImpl.onListen`, which kills the
position stream at subscription. The app then shows "Tracking...", holds a foreground service
notification, and receives not one fix. Nothing surfaces in Dart — the only evidence is
`E EventChannel#...geolocator_updates_android` in logcat.

**`geolocator`'s update interval defaults to 5 s, and it overrides the distance filter.**
Deliveries arriving inside the interval are dropped by the platform (`FusedLocation: location
delivery blocked - too fast`), so the interval, not `distanceFilter`, becomes the real sample
rate. At a 3 m/s running pace 5 s is a fix every 15 m, which rounds the corners off every loop.
`FusedSource` sets `intervalDuration` to 1 s to match the 3 m filter.

**Overpass route relations are not stored in walking order,** and many members are reversed.
Concatenating them as they arrive draws long straight chords across the map and adds their
length to the trail's — one 11.2 km route measured 15.9 km that way. `_joinMembers` chains
members on shared endpoints and drops any that will not chain.

**Calling `accelerometerEventStream()` on a host with no sensor plugin raises an *unhandled*
async error,** from a method-channel call inside the plugin that no try/catch of yours can
see. `SensorAvailability.probe` returns early off mobile, and tests override
`sensorAvailabilityProvider`.

---

## 6. Running it

```bash
flutter test                 # 77 tests, no device needed
flutter analyze              # expected: clean
dart run build_runner build  # after changing anything under data/local/
```

To see it on Android (`flutter devices` for the id):

```bash
flutter run -d emulator-5554
```

When memory is tight, build and install separately — this survives the OOM killer, because the
APK is already on disk when Gradle is torn down:

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n de.hsm.claimtrek/.MainActivity
```

`adb` is not on `PATH`; it lives at `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.

Or on web:

```bash
flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1
```

Then open `http://127.0.0.1:8080` and press **Start run**. That replays the bundled GPX at 10×
through the whole pipeline — filtering, closure detection, polygon repair, steal resolution,
persistence. Debug web is slow; the replay takes a couple of minutes and the first page load
compiles on demand.

Replay is not a demo toy. Debugging polygon clipping by walking around a car park is not a
workable loop, so the app must stay drivable indoors. Keep `ReplaySource` working.

### Known gaps in verification

- **Android runs.** First successful build 2026-09-08 on a Pixel 9a emulator (API 36). The
  replay closes its loop and claims 10.62 ha, taking 1.42 ha from 3 rivals — the same numbers
  the web target produces, so drift, clipper2 and the SQLite commit agree across platforms.
- **The sensors and the foreground service are still unexercised**, on any platform. They are
  the part that cannot be tested on web at all, and nothing feeds them yet (§3.1, §3.2).
- **Browser click automation times out** against the Flutter canvas; screenshots work. On
  Android there is no such problem — `adb shell input tap <x> <y>` drives the canvas fine, so
  the emulator is the better target for automated UI verification.

---

## 7. Conventions

- Tests first for anything in `geo/` and `sensor/`, and assert **real numbers**, not just
  "something was produced". A 100 m square is 10 000 m²; a 50 m-shifted overlap leaves 5 000.
- Repositories are the only thing that touches a DAO or a network client. The UI talks to
  repositories.
- Every dependency needs a stated reason.
- Prefer small, reversible commits, one feature each.
- No stub that throws `UnimplementedError` in committed code. That is the exact failure that
  cost this project a day.

## 8. Design document

`docs/superpowers/specs/2026-09-07-claimtrek-flutter-design.md` holds the full design, the
rejected alternatives and the reasoning behind the decisions above. It is kept current; update
it when a decision changes rather than letting it drift.
