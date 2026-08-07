import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/earnings/earnings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureAndroidMaps();
  runApp(const ProviderScope(child: MaxRideDriverApp()));
}

/// Tune Android Google Maps for emulator stability.
void _configureAndroidMaps() {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final impl = GoogleMapsFlutterPlatform.instance;
    if (impl is GoogleMapsFlutterAndroid) {
      // Hybrid composition (SurfaceView) is usually more stable than texture
      // mode on x86 / 16k emulators that die on maps_core GL init.
      impl.useAndroidViewSurface = true;
    }
  } catch (_) {}
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const DriverHomeScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: '/earnings', builder: (_, __) => const EarningsScreen()),
    ],
  );
});

class MaxRideDriverApp extends ConsumerWidget {
  const MaxRideDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'MaX Ride Driver',
      debugShowCheckedModeBanner: false,
      theme: buildDriverTheme(GoogleFonts.spaceGroteskTextTheme()),
      routerConfig: router,
    );
  }
}
