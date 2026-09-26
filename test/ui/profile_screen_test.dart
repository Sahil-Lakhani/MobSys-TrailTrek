import 'package:claimtrek/data/local/database.dart';
import 'package:claimtrek/data/player_identity.dart';
import 'package:claimtrek/data/providers.dart';
import 'package:claimtrek/ui/auth/edit_profile_screen.dart';
import 'package:claimtrek/ui/auth/profile_screen.dart';
import 'package:claimtrek/ui/tracking/tracking_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The profile only reads the territory list from the controller; the real one would open a
/// database and ask for location on build.
class _IdleController extends TrackingController {
  @override
  TrackingState build() => const TrackingState.initial();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<PlayerIdentity> pump(
    WidgetTester tester, {
    bool firebaseReady = false,
  }) async {
    // Tall enough that the whole profile is built without scrolling.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final player = await PlayerIdentity.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(firebaseReady),
          playerIdentityProvider.overrideWith((ref) async => player),
          trackingControllerProvider.overrideWith(_IdleController.new),
          runsProvider.overrideWith((ref) => Stream<List<Run>>.value(const [])),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return player;
  }

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
  }

  Finder field(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
    matching: find.byType(TextFormField),
  );

  group('the profile', () {
    testWidgets('shows who you are, read-only', (tester) async {
      SharedPreferences.setMockInitialValues({
        'player_name': 'Rezz',
        'player_handle': 'trail_rezz',
        'player_status': 'Training for a 10k',
        'player_bio': 'Hills over flats.',
      });
      await pump(tester);

      expect(find.text('Rezz'), findsOneWidget);
      expect(find.text('@trail_rezz'), findsOneWidget);
      expect(find.text('Training for a 10k'), findsOneWidget);
      expect(find.text('Hills over flats.'), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'nothing is edited in place — that is what Edit is for',
      );
    });

    testWidgets('an empty profile shows no blank sections', (tester) async {
      await pump(tester);
      expect(find.text('ABOUT ME'), findsNothing);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('shows your stats', (tester) async {
      await pump(tester);
      expect(find.text('STATS'), findsOneWidget);
      expect(find.text('0 km²'), findsOneWidget);
    });

    testWidgets('offline, no account controls are offered at all', (tester) async {
      // A build where Firebase never started must not show a sign-in button that cannot work.
      await pump(tester, firebaseReady: false);

      expect(find.text('PLAYING OFFLINE'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets('the testing reset is offered while testing tools are on', (tester) async {
      await pump(tester);
      expect(find.text('Reset captured ground'), findsOneWidget);
    });
  });

  group('editing', () {
    TextButton saveButton(WidgetTester tester) => tester.widget<TextButton>(
      find.ancestor(of: find.text('Save'), matching: find.byType(TextButton)),
    );

    testWidgets('Save stays disabled until something changes', (tester) async {
      await pump(tester);
      await openEditor(tester);
      expect(saveButton(tester).onPressed, isNull);

      await tester.enterText(field('Display name'), 'Trail runner');
      await tester.pump();
      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('everything is saved together and shown on the profile', (tester) async {
      final player = await pump(tester);
      await openEditor(tester);

      await tester.enterText(field('Display name'), 'Trail runner');
      await tester.enterText(field('Username'), 'Trail Runner');
      await tester.enterText(field('Status'), 'Out on the hills');
      await tester.enterText(field('About me'), 'Loops only.');
      await tester.tap(find.bySemanticsLabel('Colour ${playerColours[3]}'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(player.name, 'Trail runner');
      expect(player.handle, 'trail_runner', reason: 'usernames are normalised');
      expect(player.status, 'Out on the hills');
      expect(player.bio, 'Loops only.');
      expect(player.colorHex, playerColours[3]);

      expect(find.byType(EditProfileScreen), findsNothing, reason: 'Save closes the editor');
      expect(find.text('@trail_runner'), findsOneWidget);
    });

    testWidgets('an invalid username is refused', (tester) async {
      final player = await pump(tester);
      await openEditor(tester);

      await tester.enterText(field('Username'), '!');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2–20 characters'), findsOneWidget);
      expect(player.handle, isNull);
    });

    testWidgets('closing with unsaved changes asks first, and keeps nothing', (tester) async {
      final player = await pump(tester);
      await openEditor(tester);

      await tester.enterText(field('Status'), 'Half typed');
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(player.status, isNull);
    });

    testWidgets('closing with no changes just closes', (tester) async {
      await pump(tester);
      await openEditor(tester);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(EditProfileScreen), findsNothing);
    });
  });

  test('usernames are folded into shape', () {
    expect(PlayerIdentity.normaliseHandle('  Trail Runner! '), 'trail_runner');
    expect(PlayerIdentity.handlePattern.hasMatch('trail_runner'), isTrue);
    expect(PlayerIdentity.handlePattern.hasMatch('a'), isFalse);
  });
}
