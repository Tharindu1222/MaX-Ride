import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const LatLng kColomboCenter = LatLng(6.9271, 79.8612);

/// Camera lock for Sri Lanka only (slight ocean padding around the island).
final LatLngBounds kSriLankaBounds = LatLngBounds(
  southwest: const LatLng(5.8, 79.4),
  northeast: const LatLng(9.9, 82.1),
);

final CameraTargetBounds kSriLankaCameraBounds =
    CameraTargetBounds(kSriLankaBounds);

/// Zoom 7 fills the island; users cannot zoom out to other countries.
const MinMaxZoomPreference kSriLankaZoom = MinMaxZoomPreference(7, 21);

bool isInSriLanka(LatLng p) {
  return p.latitude >= kSriLankaBounds.southwest.latitude &&
      p.latitude <= kSriLankaBounds.northeast.latitude &&
      p.longitude >= kSriLankaBounds.southwest.longitude &&
      p.longitude <= kSriLankaBounds.northeast.longitude;
}

/// Simulator GPS defaults to SF; keep the camera inside the Maps bounds or tiles go blank.
LatLng cameraFocusOrColombo(LatLng? p) {
  if (p != null && isInSriLanka(p)) return p;
  return kColomboCenter;
}

bool get mapsSupported {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}

num? parseCoord(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) return num.tryParse(value.trim());
  return num.tryParse(value.toString());
}

LatLng? latLngFrom(dynamic lat, dynamic lng) {
  final a = parseCoord(lat);
  final b = parseCoord(lng);
  if (a == null || b == null) return null;
  return LatLng(a.toDouble(), b.toDouble());
}

LatLngBounds boundsFromPoints(List<LatLng> points) {
  final lats = points.map((p) => p.latitude);
  final lngs = points.map((p) => p.longitude);
  return LatLngBounds(
    southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
    northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
  );
}

Future<BitmapDescriptor> bitmapFromEmoji(
  String emoji, {
  double size = 40,
  Color ring = const Color(0xFF1565C0),
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final tp = TextPainter(
    text: TextSpan(
      text: emoji,
      style: TextStyle(fontSize: size * 0.62, height: 1),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  const pad = 6.0;
  final w = math.max(tp.width + pad * 2, size);
  final h = math.max(tp.height + pad * 2, size);
  final center = Offset(w / 2, h / 2);
  final radius = math.min(w, h) / 2;
  canvas.drawCircle(center, radius, Paint()..color = Colors.white);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  tp.paint(
    canvas,
    Offset((w - tp.width) / 2, (h - tp.height) / 2 - 1),
  );
  final image = await recorder.endRecording().toImage(w.ceil(), h.ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

/// Driver / navigation map with markers + route polyline + optional follow me.
class RideMap extends StatefulWidget {
  const RideMap({
    super.key,
    this.pickup,
    this.dropoff,
    this.driver,
    this.destination,
    this.routePoints = const [],
    this.myLocationEnabled = true,
    this.followDriver = false,
    this.navigationMode = false,
    this.driverHeading,
    this.driverEmoji,
    this.passengerEmoji,
    this.height,
    this.borderRadius = 0,
    this.routeColor = const Color(0xFF1565C0),
    this.onMapCreated,
    this.onCameraMoveStarted,
  });

  final LatLng? pickup;
  final LatLng? dropoff;
  final LatLng? driver;
  final LatLng? destination;
  final List<LatLng> routePoints;
  final bool myLocationEnabled;
  /// When true, camera gently follows [driver] on updates.
  final bool followDriver;
  /// Turn-by-turn style camera (zoom + heading). Follows even with a route drawn.
  final bool navigationMode;
  final double? driverHeading;
  /// Vehicle emoji for the live driver pin (e.g. 🚗 🛺 🚐).
  final String? driverEmoji;
  /// Person emoji at pickup (e.g. 🧍).
  final String? passengerEmoji;
  final double? height;
  final double borderRadius;
  final Color routeColor;
  final void Function(GoogleMapController controller)? onMapCreated;
  final VoidCallback? onCameraMoveStarted;

  @override
  State<RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<RideMap> {
  GoogleMapController? _controller;
  bool _programmaticCamera = false;
  BitmapDescriptor? _vehicleIcon;
  String? _vehicleEmoji;
  BitmapDescriptor? _passengerIcon;
  String? _loadedPassengerEmoji;

  @override
  void initState() {
    super.initState();
    _ensureIcons();
  }

  Future<void> _ensureIcons() async {
    try {
      final vehicle = widget.driverEmoji ?? '🚗';
      if (vehicle != _vehicleEmoji) {
        final icon = await bitmapFromEmoji(
          vehicle,
          size: 36,
          ring: const Color(0xFF1565C0),
        );
        if (!mounted) return;
        setState(() {
          _vehicleIcon = icon;
          _vehicleEmoji = vehicle;
        });
      }
      final person = widget.passengerEmoji;
      if (person != null &&
          person.isNotEmpty &&
          person != _loadedPassengerEmoji) {
        final icon = await bitmapFromEmoji(
          person,
          size: 36,
          ring: const Color(0xFF2E7D32),
        );
        if (!mounted) return;
        setState(() {
          _passengerIcon = icon;
          _loadedPassengerEmoji = person;
        });
      } else if (person == null && _passengerIcon != null) {
        setState(() {
          _passengerIcon = null;
          _loadedPassengerEmoji = null;
        });
      }
    } catch (_) {}
  }

  Set<Marker> get _markers {
    final set = <Marker>{};
    if (widget.pickup != null) {
      set.add(Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickup!,
        infoWindow: InfoWindow(
          title: widget.passengerEmoji != null ? 'Passenger' : 'Passenger pickup',
        ),
        icon: _passengerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: widget.passengerEmoji != null
            ? const Offset(0.5, 0.5)
            : const Offset(0.5, 1),
        zIndexInt: 3,
      ));
    }
    if (widget.dropoff != null) {
      set.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: widget.dropoff!,
        infoWindow: const InfoWindow(title: 'Drop-off'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    // Custom live pin (always show driver when we have a fix to draw)
    if (widget.driver != null) {
      set.add(Marker(
        markerId: const MarkerId('me'),
        position: widget.driver!,
        rotation: widget.driverHeading ?? 0,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'You (live)'),
        icon: _vehicleIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        zIndexInt: 4,
      ));
    }
    if (widget.destination != null &&
        widget.destination != widget.pickup &&
        widget.destination != widget.dropoff) {
      set.add(Marker(
        markerId: const MarkerId('dest'),
        position: widget.destination!,
        infoWindow: const InfoWindow(title: 'Navigate here'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }
    return set;
  }

  Set<Polyline> get _polylines {
    if (widget.routePoints.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('nav_route'),
        points: widget.routePoints,
        color: widget.routeColor,
        width: 6,
      ),
    };
  }

  CameraPosition get _initial {
    final focus = cameraFocusOrColombo(
      widget.driver ?? widget.destination ?? widget.pickup,
    );
    return CameraPosition(
      target: focus,
      zoom: focus == kColomboCenter && widget.driver == null ? 12 : 16,
      bearing: widget.driverHeading ?? 0,
    );
  }

  Future<void> _fitRoute() async {
    final c = _controller;
    if (c == null) return;
    final pts = <LatLng>[
      ...widget.routePoints,
      if (widget.driver != null) widget.driver!,
      if (widget.destination != null) widget.destination!,
      if (widget.routePoints.isEmpty && widget.pickup != null) widget.pickup!,
      if (widget.routePoints.isEmpty && widget.dropoff != null) widget.dropoff!,
    ];
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      await c.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 16));
      return;
    }
    try {
      await c.animateCamera(
        CameraUpdate.newLatLngBounds(boundsFromPoints(pts), 72),
      );
    } catch (_) {
      await c.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 15));
    }
  }

  Future<void> _followMe() async {
    final c = _controller;
    final d = widget.driver;
    if (c == null || d == null || !widget.followDriver) return;
    // Outside Sri Lanka (e.g. iOS Simulator default) — stay on Colombo tiles.
    if (!isInSriLanka(d)) return;
    _programmaticCamera = true;
    try {
      if (widget.navigationMode) {
        await c.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: d,
              zoom: 17.2,
              tilt: 0,
              bearing: widget.driverHeading ?? 0,
            ),
          ),
        );
      } else {
        await c.moveCamera(CameraUpdate.newLatLng(d));
      }
    } catch (_) {
    } finally {
      Future.delayed(const Duration(milliseconds: 400), () {
        _programmaticCamera = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant RideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driverEmoji != widget.driverEmoji ||
        oldWidget.passengerEmoji != widget.passengerEmoji) {
      _ensureIcons();
    }
    final routeChanged =
        oldWidget.routePoints.length != widget.routePoints.length ||
            oldWidget.destination != widget.destination ||
            oldWidget.pickup != widget.pickup ||
            oldWidget.dropoff != widget.dropoff;
    final driverMoved = oldWidget.driver != widget.driver ||
        oldWidget.driverHeading != widget.driverHeading;

    if (widget.navigationMode && widget.followDriver) {
      if (driverMoved || routeChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _followMe());
      }
      return;
    }

    if (routeChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    } else if (driverMoved && widget.followDriver) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _followMe());
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = !mapsSupported
        ? Container(
            color: const Color(0xFF1A2332),
            alignment: Alignment.center,
            child: const Text(
              'Maps: use Android/iOS device',
              style: TextStyle(color: Colors.white70),
            ),
          )
        : GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initial,
            cameraTargetBounds: kSriLankaCameraBounds,
            minMaxZoomPreference: kSriLankaZoom,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: widget.myLocationEnabled,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: widget.navigationMode,
            mapToolbarEnabled: false,
            trafficEnabled: false, // less GPU load (avoids emulator GL crashes)
            buildingsEnabled: false,
            indoorViewEnabled: false,
            tiltGesturesEnabled: false,
            onCameraMoveStarted: () {
              if (!_programmaticCamera) widget.onCameraMoveStarted?.call();
            },
            onMapCreated: (c) {
              _controller = c;
              widget.onMapCreated?.call(c);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (widget.navigationMode && widget.followDriver) {
                  _followMe();
                } else if (widget.routePoints.length >= 2) {
                  _fitRoute();
                } else if (widget.driver != null &&
                    isInSriLanka(widget.driver!)) {
                  c.moveCamera(
                    CameraUpdate.newLatLngZoom(widget.driver!, 15.5),
                  );
                }
              });
            },
          );

    final map = widget.borderRadius > 0
        ? ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: child,
          )
        : child;

    if (widget.height != null) {
      return SizedBox(height: widget.height, width: double.infinity, child: map);
    }
    return map;
  }
}
