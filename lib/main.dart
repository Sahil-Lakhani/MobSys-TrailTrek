import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'firebase_options.dart';
import 'ui/app.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw under the status and gesture bars; the map is meant to run edge to edge.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Firebase is not allowed to be the reason the app will not open. Everything the game is
  // actually about — capturing ground, the map, run history — runs off the local database and
  // needs no account at all, so a project that is misconfigured, offline or simply not set up
  // yet degrades to local-only play rather than a blank screen.
  //
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (error, stack) {
    debugPrint('ClaimTrek: Firebase unavailable, running local-only: $error');
    debugPrintStack(stackTrace: stack);
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWith((ref) => firebaseReady),
      ],
      child: const ClaimTrekApp(),
    ),
  );
}

class ClaimTrekApp extends StatelessWidget {
  const ClaimTrekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ClaimTrek',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      // One dark theme whatever the phone is set to: the chrome floats over a light map, and
      // it is the contrast between the two that keeps the controls findable mid-stride.
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
    );
  }
}
