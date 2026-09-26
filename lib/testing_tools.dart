/// The one switch for tools that exist only to make the app testable by hand.
///
/// ═══ TESTING ONLY ═══════════════════════════════════════════════════════════════════════
/// Set this to `false` for the final version. Every testing-only control checks it, so
/// flipping it here hides all of them without touching anything else:
///
///  - "Reset captured ground" on the Profile tab
///    UI:       lib/ui/auth/profile_screen.dart          → `_TestingToolsCard`
///    Logic:    lib/ui/tracking/tracking_controller.dart → `resetGroundForTesting()`
///    Storage:  lib/data/territory_repository.dart       → `resetGroundForTesting()`
/// ════════════════════════════════════════════════════════════════════════════════════════
const bool kShowTestingTools = true;
