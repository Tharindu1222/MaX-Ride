import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

const _envApi = String.fromEnvironment('API_BASE_URL');
const _envWs = String.fromEnvironment('WS_URL');

/// Resolved in [initDevEndpoints] before `runApp`.
late final String kApiBaseUrl;
late final String kWsUrl;

Future<void> initDevEndpoints() async {
  var api = _envApi;
  if (api.isEmpty) {
    final origin = await _defaultOrigin();
    api = '$origin/api/v1';
    kWsUrl = _envWs.isNotEmpty ? _envWs : '$origin/realtime';
  } else {
    if (await isPhysicalAndroid()) {
      api = api
          .replaceAll('http://10.0.2.2:', 'http://127.0.0.1:')
          .replaceAll('https://10.0.2.2:', 'https://127.0.0.1:');
    }
    kWsUrl = _envWs.isNotEmpty ? _envWs : _wsFromApi(api);
  }
  kApiBaseUrl = api;
  debugPrint('MaX Ride API → $kApiBaseUrl');
}

String _wsFromApi(String api) {
  if (api.endsWith('/api/v1')) {
    return '${api.substring(0, api.length - '/api/v1'.length)}/realtime';
  }
  return '$api/realtime';
}

Future<String> _defaultOrigin() async {
  if (kIsWeb) return 'http://localhost:4000';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
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
