import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Colombo Fort — default camera center for MaX Ride demo.
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

/// Parses lat/lng from num, int, double, or String (API JSON is not always typed).
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

double? coordAsDouble(dynamic value) => parseCoord(value)?.toDouble();

String fmtCoord(LatLng p) =>
    '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

LatLngBounds boundsFromPoints(List<LatLng> points) {
  final lats = points.map((p) => p.latitude);
  final lngs = points.map((p) => p.longitude);
  return LatLngBounds(
    southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
    northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
  );
}

/// Full-bleed Google Map with pickup / dropoff / driver markers.
class RideMap extends StatefulWidget {
  const RideMap({
    super.key,
    this.pickup,
    this.dropoff,
    this.driver,
    this.myLocationEnabled = true,
    this.interactive = true,
    this.onMapCreated,
    this.onTap,
    this.onLongPress,
    this.onCameraMove,
    this.onCameraIdle,
    this.onPickupDragEnd,
    this.onDropoffDragEnd,
    this.height,
    this.borderRadius = 0,
    this.showRoute = true,
    this.routePoints = const [],
  });

  final LatLng? pickup;
  final LatLng? dropoff;
  final LatLng? driver;
  final bool myLocationEnabled;
  final bool interactive;
  final void Function(GoogleMapController controller)? onMapCreated;
  final void Function(LatLng position)? onTap;
  final void Function(LatLng position)? onLongPress;
  final void Function(CameraPosition position)? onCameraMove;
  final VoidCallback? onCameraIdle;
  final void Function(LatLng position)? onPickupDragEnd;
  final void Function(LatLng position)? onDropoffDragEnd;
  final double? height;
  final double borderRadius;
  final bool showRoute;
  /// Google Directions polyline (driver → next stop for passenger tracking).
  final List<LatLng> routePoints;

  @override
  State<RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<RideMap> {
  GoogleMapController? _controller;

  Set<Marker> get _markers {
    final set = <Marker>{};
    if (widget.pickup != null) {
      set.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickup!,
          infoWindow: const InfoWindow(title: 'Pickup'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          draggable: widget.onPickupDragEnd != null,
          onDragEnd: widget.onPickupDragEnd,
        ),
      );
    }
    if (widget.dropoff != null) {
      set.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: widget.dropoff!,
          infoWindow: const InfoWindow(title: 'Drop-off'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          draggable: widget.onDropoffDragEnd != null,
          onDragEnd: widget.onDropoffDragEnd,
        ),
      );
    }
    if (widget.driver != null) {
      set.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: widget.driver!,
          infoWindow: const InfoWindow(title: 'Driver'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
    return set;
  }

  Set<Polyline> get _polylines {
    if (widget.routePoints.length >= 2) {
      return {
        Polyline(
          polylineId: const PolylineId('live_route'),
          points: widget.routePoints,
          color: const Color(0xFF1565C0),
          width: 5,
        ),
      };
    }
    if (!widget.showRoute ||
        widget.pickup == null ||
        widget.dropoff == null) {
      return {};
    }
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [widget.pickup!, widget.dropoff!],
        color: const Color(0xFF0F3D2E),
        width: 4,
        patterns: [PatternItem.dash(16), PatternItem.gap(8)],
      ),
    };
  }

  CameraPosition get _initial {
    final focus =
        widget.pickup ?? widget.driver ?? widget.dropoff ?? kColomboCenter;
    return CameraPosition(target: focus, zoom: 14);
  }

  Future<void> _fitBounds() async {
    final c = _controller;
    if (c == null) return;
    final pts = <LatLng>[
      ...widget.routePoints,
      if (widget.pickup != null) widget.pickup!,
      if (widget.dropoff != null) widget.dropoff!,
      if (widget.driver != null) widget.driver!,
    ];
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      await c.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 15));
      return;
    }
    try {
      await c.animateCamera(
        CameraUpdate.newLatLngBounds(boundsFromPoints(pts), 80),
      );
    } catch (_) {
      await c.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 14));
    }
  }

  @override
  void didUpdateWidget(covariant RideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bothNew = widget.pickup != null &&
        widget.dropoff != null &&
        (oldWidget.pickup == null || oldWidget.dropoff == null);
    if (bothNew ||
        oldWidget.driver != widget.driver ||
        oldWidget.routePoints.length != widget.routePoints.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = !mapsSupported
        ? const _MapsUnsupported()
        : GoogleMap(
            initialCameraPosition: _initial,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: widget.myLocationEnabled,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            scrollGesturesEnabled: widget.interactive,
            zoomGesturesEnabled: widget.interactive,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onCameraMove: widget.onCameraMove,
            onCameraIdle: widget.onCameraIdle,
            onMapCreated: (c) {
              _controller = c;
              widget.onMapCreated?.call(c);
              WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
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

class _MapsUnsupported extends StatelessWidget {
  const _MapsUnsupported();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A3A2E),
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Google Maps runs on Android / iOS.\n'
          'Use an emulator or physical phone for map tiles.\n'
          'Do a full restart after adding the Maps plugin (not hot reload).',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      ),
    );
  }
}
