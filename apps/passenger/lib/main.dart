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
import 'features/home/home_screen.dart';
import 'features/ride/active_ride_screen.dart';
import 'features/history/history_screen.dart';
import 'features/profile/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await initDevEndpoints();
  await configureAndroidMaps();
  runApp(const ProviderScope(child: MaxRidePassengerApp()));
}

Future<void> configureAndroidMaps() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final impl = GoogleMapsFlutterPlatform.instance;
    if (impl is! GoogleMapsFlutterAndroid) return;
    final physical = await isPhysicalAndroid();
    try {
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
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/ride/:id',
        builder: (_, state) =>
            ActiveRideScreen(rideId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
  );
});

class MaxRidePassengerApp extends ConsumerWidget {
  const MaxRidePassengerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'MaX Ride',
      debugShowCheckedModeBanner: false,
      theme: buildMaxRideTheme(GoogleFonts.plusJakartaSansTextTheme()),
      routerConfig: router,
    );
  }
}
