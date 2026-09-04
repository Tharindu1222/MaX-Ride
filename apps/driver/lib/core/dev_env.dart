import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

const _envApi = String.fromEnvironment('API_BASE_URL');

/// Resolved in [initDevEndpoints] before `runApp`.
late final String kApiBaseUrl;

Future<void> initDevEndpoints() async {
  var api = _envApi;
  if (api.isEmpty) {
    api = '${await _defaultOrigin()}/api/v1';
  } else if (await isPhysicalAndroid()) {
    // README / habit often passes 10.0.2.2 — that only works in the emulator.
    // Physical USB devices need adb reverse + loopback (or a LAN IP dart-define).
    api = api
        .replaceAll('http://10.0.2.2:', 'http://127.0.0.1:')
        .replaceAll('https://10.0.2.2:', 'https://127.0.0.1:');
  }
  kApiBaseUrl = api;
  debugPrint('MaX Ride API → $kApiBaseUrl');
}

Future<String> _defaultOrigin() async {
  if (kIsWeb) return 'http://localhost:4000';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // Emulator host loopback. Physical USB: `adb reverse tcp:4000 tcp:4000`.
      if (await isPhysicalAndroid()) return 'http://127.0.0.1:4000';
      return 'http://10.0.2.2:4000';
    default:
      return 'http://127.0.0.1:4000';
  }
}

Future<bool> isPhysicalAndroid() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  return isPhysicalDevice();
}

Future<bool> isPhysicalDevice() async {
  if (kIsWeb) return false;
  try {
    final plugin = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return (await plugin.androidInfo).isPhysicalDevice;
      case TargetPlatform.iOS:
        return (await plugin.iosInfo).isPhysicalDevice;
      default:
        return true;
    }
  } catch (_) {
    return true;
  }
}
