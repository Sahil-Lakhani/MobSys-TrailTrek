import 'dart:async';

import 'package:claimtrek/data/providers.dart';
import 'package:claimtrek/ui/app.dart';
import 'package:claimtrek/ui/auth/sign_in_screen.dart';
import 'package:claimtrek/ui/auth/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, Stream<User?> auth) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(true),
          authStateProvider.overrideWith((ref) => auth),
        ],
        child: Consumer(
          builder: (context, ref, _) =>
              MaterialApp.router(routerConfig: ref.watch(routerProvider)),
        ),
      ),
    );
  }

  testWidgets('holds on the splash until the saved session is known', (
    tester,
  ) async {
    // Never answers: Firebase still restoring the session.
    final auth = StreamController<User?>();
    addTearDown(auth.close);

    await pumpApp(tester, auth.stream);
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('signed out, the sign-in screen is all there is', (tester) async {
    await pumpApp(tester, Stream.value(null));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    // No way around it: the tab bar is not on screen.
    expect(find.text('Board'), findsNothing);
  });

  testWidgets('signing out mid-session returns to sign-in', (tester) async {
    final auth = StreamController<User?>();
    addTearDown(auth.close);

    await pumpApp(tester, auth.stream);
    auth.add(null);
    await tester.pump();
    await tester.pump();

    expect(find.byType(SignInScreen), findsOneWidget);
  });
}
