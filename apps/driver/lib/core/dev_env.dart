import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

const _envApi = String.fromEnvironment('API_BASE_URL');

/// Resolved in [initDevEndpoints] before `runApp`.
late final String kApiBaseUrl;

Future<void> initDevEndpoints() async {
  var api = _envApi;
  if (api.isEmpty) {
    api = '${await _defaultOrigin()}/api/v1';
  }

  // 10.0.2.2 only works inside the Android emulator. Physical devices (USB)
  // need host loopback via `adb reverse tcp:4000 tcp:4000`, or a LAN IP dart-define.
  if (defaultTargetPlatform == TargetPlatform.android &&
      await isPhysicalAndroid() &&
      api.contains('10.0.2.2')) {
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
      // Emulator → special host alias. Physical USB → adb reverse to loopback.
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
        final info = await plugin.androidInfo;
        if (info.isPhysicalDevice) return true;
        // Some devices mis-report; treat obvious emulator fingerprints only.
        final blob =
            '${info.fingerprint} ${info.model} ${info.product} ${info.hardware}'
                .toLowerCase();
        final emulatorHints = [
          'generic',
          'emulator',
          'sdk_gphone',
          'sdk_google',
          'goldfish',
          'ranchu',
          'vbox',
        ];
        return !emulatorHints.any(blob.contains);
      case TargetPlatform.iOS:
        return (await plugin.iosInfo).isPhysicalDevice;
      default:
        return true;
    }
  } catch (_) {
    // Prefer physical/USB path so 10.0.2.2 is not used by mistake.
    return true;
  }
}
