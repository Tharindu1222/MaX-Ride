import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/ride/active_ride_screen.dart';
import 'features/history/history_screen.dart';
import 'features/profile/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MaxRidePassengerApp()));
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
      theme: buildMaxRideTheme(GoogleFonts.dmSansTextTheme()),
      routerConfig: router,
    );
  }
}
