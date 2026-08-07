import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const LatLng kColomboCenter = LatLng(6.9271, 79.8612);

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
    this.driverHeading,
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
  final double? driverHeading;
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

  Set<Marker> get _markers {
    final set = <Marker>{};
    if (widget.pickup != null) {
      set.add(Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickup!,
        infoWindow: const InfoWindow(title: 'Passenger pickup'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        zIndexInt: 3,
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
    final focus = widget.driver ??
        widget.destination ??
        widget.pickup ??
        kColomboCenter;
    return CameraPosition(
      target: focus,
      zoom: 16,
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
    if (widget.routePoints.length >= 2) return;
    // moveCamera is cheaper / safer than animate on weak emulators
    try {
      await c.moveCamera(CameraUpdate.newLatLng(d));
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant RideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged =
        oldWidget.routePoints.length != widget.routePoints.length ||
            oldWidget.destination != widget.destination;
    final driverMoved = oldWidget.driver != widget.driver ||
        oldWidget.driverHeading != widget.driverHeading;

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
            initialCameraPosition: _initial,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: widget.myLocationEnabled,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            trafficEnabled: false, // less GPU load (avoids emulator GL crashes)
            buildingsEnabled: false,
            indoorViewEnabled: false,
            tiltGesturesEnabled: false,
            onCameraMoveStarted: widget.onCameraMoveStarted,
            onMapCreated: (c) {
              _controller = c;
              widget.onMapCreated?.call(c);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (widget.routePoints.length >= 2) {
                  _fitRoute();
                } else if (widget.driver != null) {
                  // One-time frame on first create — avoid continuous animate storms
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
