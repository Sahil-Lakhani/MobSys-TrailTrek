import 'package:claimtrek/data/player_identity.dart';
import 'package:claimtrek/data/providers.dart';
import 'package:claimtrek/ui/auth/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<PlayerIdentity> pump(
    WidgetTester tester, {
    bool firebaseReady = false,
  }) async {
    final player = await PlayerIdentity.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(firebaseReady),
          playerIdentityProvider.overrideWith((ref) async => player),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return player;
  }

  testWidgets('the profile offers a name and a colour', (tester) async {
    await pump(tester);

    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Your colour'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a typed name is saved to the identity', (tester) async {
    final player = await pump(tester);

    await tester.enterText(find.byType(TextField), 'Trail runner');
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();

    expect(player.name, 'Trail runner');
  });

  testWidgets('choosing a colour stores it', (tester) async {
    final player = await pump(tester);
    expect(player.colorHex, PlayerIdentity.playerColor);

    // The second swatch; the first is already the default.
    await tester.tap(find.bySemanticsLabel('Colour ${playerColours[3]}'));
    await tester.pumpAndSettle();

    expect(player.colorHex, playerColours[3]);
  });

  testWidgets('offline, no account controls are offered at all', (tester) async {
    // A build where Firebase never started must not show a sign-in button that cannot work.
    await pump(tester, firebaseReady: false);

    expect(find.text('Playing offline'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
  });
}
