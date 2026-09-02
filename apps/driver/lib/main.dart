import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'core/dev_env.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/earnings/earnings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await initDevEndpoints();
  await configureAndroidMaps();
  runApp(const ProviderScope(child: MaxRideDriverApp()));
}

/// Physical devices + Impeller: TextureLayer (not SurfaceView) so map tiles paint.
/// Emulators keep hybrid SurfaceView — x86/16k images crash in maps_core GL otherwise.
Future<void> configureAndroidMaps() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final impl = GoogleMapsFlutterPlatform.instance;
    if (impl is! GoogleMapsFlutterAndroid) return;
    final physical = await isPhysicalAndroid();
    try {
      // Legacy renderer paints tiles on more Samsung/tablet GPUs; latest is fine on emulators.
      await impl.initializeWithRenderer(
        physical ? AndroidMapRenderer.legacy : AndroidMapRenderer.latest,
      );
    } catch (_) {
      try {
        await impl.initializeWithRenderer(AndroidMapRenderer.latest);
      } catch (_) {}
    }
    impl.useAndroidViewSurface = !physical;
  } catch (_) {}
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
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
      theme: buildDriverTheme(GoogleFonts.plusJakartaSansTextTheme()),
      routerConfig: router,
    );
  }
}
