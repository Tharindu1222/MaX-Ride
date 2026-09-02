import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

const _envApi = String.fromEnvironment('API_BASE_URL');
const _envWs = String.fromEnvironment('WS_URL');

/// Resolved in [initDevEndpoints] before `runApp`.
late final String kApiBaseUrl;
late final String kWsUrl;

Future<void> initDevEndpoints() async {
  if (_envApi.isNotEmpty) {
    kApiBaseUrl = _envApi;
    kWsUrl = _envWs.isNotEmpty ? _envWs : _wsFromApi(_envApi);
    return;
  }
  final origin = await _defaultOrigin();
  kApiBaseUrl = '$origin/api/v1';
  kWsUrl = _envWs.isNotEmpty ? _envWs : '$origin/realtime';
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
