import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/api_client.dart';
import '../../core/dev_env.dart';
import '../../core/theme.dart';
import '../../widgets/max_ui.dart';
import '../../widgets/ride_map.dart';

enum PickTarget { pickup, dropoff }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List categories = [];
  Map<String, dynamic>? pickup;
  Map<String, dynamic>? dropoff;
  String? selectedCategoryId;
  String paymentMethod = 'CASH';
  String promo = '';
  bool promoOpen = false;
  Map<String, dynamic>? estimate;
  bool loading = false;
  bool estimating = false;
  String? error;

  /// Which location the user is currently setting (map pin / search).
  PickTarget activeTarget = PickTarget.pickup;

  LatLng cameraTarget = kColomboCenter;
  GoogleMapController? mapController;
  bool mapReady = false;

  final searchCtrl = TextEditingController();
  final searchFocus = FocusNode();
  List<Map<String, dynamic>> searchResults = [];
  bool searching = false;
  bool showSearchPanel = false;
  Timer? searchDebounce;
  Timer? estimateDebounce;

  String? searchProvider;
  String? searchWarning;
  bool locating = false;
  bool _physicalDevice = true;
  bool _didAutoLocate = false;

  LatLng? get pickupLatLng => latLngFrom(pickup?['lat'], pickup?['lng']);
  LatLng? get dropoffLatLng => latLngFrom(dropoff?['lat'], dropoff?['lng']);

  bool get canBook =>
      pickup != null && dropoff != null && selectedCategoryId != null;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _preloadPopular();
    isPhysicalDevice().then((v) {
      if (mounted) _physicalDevice = v;
    });
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    estimateDebounce?.cancel();
    searchCtrl.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final api = ref.read(apiClientProvider);
      final cats = await api.get('/vehicle-categories');
      if (!mounted) return;
      setState(() {
        categories = (cats['data'] as List?) ?? [];
        if (categories.isNotEmpty) {
          selectedCategoryId = categories.first['id'] as String?;
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _preloadPopular() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/maps/places/popular');
      final list = ((res['data'] as Map?)?['results'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        searchResults = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      searching = true;
      searchWarning = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final bias = pickupLatLng ?? cameraTarget;
      final q = Uri.encodeQueryComponent(query.trim());
      final path = query.trim().isEmpty
          ? '/maps/places/popular'
          : '/maps/places?q=$q'
              '&lat=${bias.latitude}&lng=${bias.longitude}';
      final res = await api.get(path);
      final data = res['data'];
      List list;
      String? provider;
      String? warning;
      if (data is Map) {
        list = (data['results'] as List?) ?? [];
        provider = data['provider']?.toString();
        warning = data['warning']?.toString();
      } else if (data is List) {
        list = data;
      } else {
        list = [];
      }
      if (!mounted) return;
      setState(() {
        searchResults =
            list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        searchProvider = provider;
        searchWarning = warning;
        searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        searching = false;
        error = e.toString();
      });
      _toast('Search failed: $e');
    }
  }

  void _onSearchChanged(String value) {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _runSearch(value);
    });
  }

  Future<Map<String, dynamic>> _reverseGeocode(LatLng p) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        '/maps/geocode/reverse?lat=${p.latitude}&lng=${p.longitude}',
      );
      final raw = res['data'] is Map
          ? Map<String, dynamic>.from(res['data'] as Map)
          : res;
      return {
        'id':
            'map-${p.latitude.toStringAsFixed(5)}-${p.longitude.toStringAsFixed(5)}',
        'name': raw['name']?.toString() ?? 'Map pin',
        'address': raw['address']?.toString() ?? fmtCoord(p),
        'lat': p.latitude,
        'lng': p.longitude,
      };
    } catch (_) {
      return {
        'id':
            'map-${p.latitude.toStringAsFixed(5)}-${p.longitude.toStringAsFixed(5)}',
        'name': 'Map location',
        'address': fmtCoord(p),
        'lat': p.latitude,
        'lng': p.longitude,
      };
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    final p = latLngFrom(place['lat'], place['lng']);
    // Normalize coords to num so later API posts never send strings
    final normalized = Map<String, dynamic>.from(place);
    if (p != null) {
      normalized['lat'] = p.latitude;
      normalized['lng'] = p.longitude;
    }

    setState(() {
      if (activeTarget == PickTarget.pickup) {
        pickup = normalized;
        if (dropoff == null) activeTarget = PickTarget.dropoff;
      } else {
        dropoff = normalized;
      }
      estimate = null;
      showSearchPanel = false;
      searchCtrl.clear();
      error = null;
    });
    searchFocus.unfocus();
    _refreshEstimate();

    if (p != null) {
      await mapController?.animateCamera(CameraUpdate.newLatLngZoom(p, 15.5));
    }
  }

  Future<void> _applyMapPoint(LatLng p, {PickTarget? force}) async {
    final target = force ?? activeTarget;
    final place = await _reverseGeocode(p);
    if (!mounted) return;
    setState(() {
      if (target == PickTarget.pickup) {
        pickup = place;
        if (dropoff == null) activeTarget = PickTarget.dropoff;
      } else {
        dropoff = place;
      }
      estimate = null;
      showSearchPanel = false;
    });
    _refreshEstimate();
  }

  Future<void> _confirmCenterPin() => _applyMapPoint(cameraTarget);

  void _openTarget(PickTarget t) {
    setState(() {
      activeTarget = t;
      showSearchPanel = true;
      searchCtrl.clear();
    });
    _runSearch('');
    // Focus search so passenger can type immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchFocus.requestFocus();
    });

    // Fly map to existing point if set
    final existing =
        t == PickTarget.pickup ? pickupLatLng : dropoffLatLng;
    if (existing != null) {
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(existing, 15));
    }
  }

  LocationSettings _gpsSettings({Duration timeLimit = const Duration(seconds: 15)}) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: !_physicalDevice,
        timeLimit: timeLimit,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      timeLimit: timeLimit,
    );
  }

  /// Fresh GPS first. Last-known is only a fallback.
  Future<Position?> _resolveDevicePosition() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      _toast('Turn on Location in device settings');
      await Geolocator.openLocationSettings();
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      _toast('Location permission denied');
      return null;
    }
    if (permission == LocationPermission.deniedForever) {
      _toast('Enable location for MaX Ride in App settings');
      await Geolocator.openAppSettings();
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _gpsSettings(),
      );
    } on TimeoutException {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
      } catch (_) {}
      _toast('GPS timeout — move outdoors with Location on');
      return null;
    } catch (e) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
      } catch (_) {}
      _toast('Could not get GPS: $e');
      return null;
    }
  }

  Future<void> _goMyLocation({bool silent = false}) async {
    if (!silent) setState(() => locating = true);
    final pos = await _resolveDevicePosition();
    if (!mounted) return;
    if (!silent) setState(() => locating = false);
    if (pos == null) return;

    final me = LatLng(pos.latitude, pos.longitude);
    setState(() => cameraTarget = me);
    await mapController?.animateCamera(CameraUpdate.newLatLngZoom(me, 16));
  }

  Future<void> _useCurrentAsPickup() async {
    setState(() {
      activeTarget = PickTarget.pickup;
      locating = true;
      error = null;
    });

    final pos = await _resolveDevicePosition();
    if (!mounted) return;

    if (pos != null) {
      final me = LatLng(pos.latitude, pos.longitude);
      setState(() => cameraTarget = me);
      await mapController?.animateCamera(CameraUpdate.newLatLngZoom(me, 16));
      await _applyMapPoint(me, force: PickTarget.pickup);
      if (mounted) {
        setState(() {
          locating = false;
          showSearchPanel = false;
        });
        searchFocus.unfocus();
        _toast('Pickup set to your current location');
      }
      return;
    }

    // Fallback: use map center pin so the button still completes the action
    await _applyMapPoint(cameraTarget, force: PickTarget.pickup);
    if (!mounted) return;
    setState(() {
      locating = false;
      showSearchPanel = false;
    });
    searchFocus.unfocus();
    _toast('GPS unavailable — pan the map to set pickup.');
  }

  Future<void> _refreshEstimate() async {
    if (!canBook) return;
    setState(() => estimating = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/fares/estimate', {
        'vehicleCategoryId': selectedCategoryId,
        'pickupLat': coordAsDouble(pickup!['lat']),
        'pickupLng': coordAsDouble(pickup!['lng']),
        'dropoffLat': coordAsDouble(dropoff!['lat']),
        'dropoffLng': coordAsDouble(dropoff!['lng']),
        if (promo.isNotEmpty) 'promoCode': promo,
      });
      if (!mounted) return;
      setState(() {
        estimate = Map<String, dynamic>.from(res['data'] as Map);
        estimating = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => estimating = false);
    }
  }

  Future<void> _requestRide() async {
    if (!canBook) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/rides', {
        'vehicleCategoryId': selectedCategoryId,
        'pickupAddress': pickup!['address'] ?? pickup!['name'],
        'pickupLat': coordAsDouble(pickup!['lat']),
        'pickupLng': coordAsDouble(pickup!['lng']),
        'dropoffAddress': dropoff!['address'] ?? dropoff!['name'],
        'dropoffLat': coordAsDouble(dropoff!['lat']),
        'dropoffLng': coordAsDouble(dropoff!['lng']),
        'paymentMethod': paymentMethod,
        if (promo.isNotEmpty) 'promoCode': promo,
      });
      final ride = res['data'] as Map<String, dynamic>;
      if (!mounted) return;
      final pin = ride['startPin'];
      if (pin != null) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Your start PIN'),
            content: Text('Share this PIN with the driver: $pin'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      context.go('/ride/${ride['id']}');
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Color get _activeColor =>
      activeTarget == PickTarget.pickup ? maxPickup : maxDropoff;

  String get _confirmLabel => activeTarget == PickTarget.pickup
      ? 'Set pickup here'
      : 'Set drop-off here';

  String get _ctaHint {
    if (pickup == null) return 'Choose pickup';
    if (dropoff == null) return 'Choose drop-off';
    return 'Ready to request';
  }

  String? get _fareLine {
    final e = estimate;
    if (e == null) return null;
    final fare = e['estimatedFare'];
    final mins = ((e['estimatedDurationSeconds'] as num?) ?? 0) / 60;
    return 'LKR $fare · ${mins.round()} min';
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final sheetMax = MediaQuery.sizeOf(context).height *
        (showSearchPanel ? 0.28 : 0.40);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: maxSand,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RideMap(
              pickup: pickupLatLng,
              dropoff: dropoffLatLng,
              myLocationEnabled: true,
              interactive: true,
              showRoute: pickupLatLng != null && dropoffLatLng != null,
              onMapCreated: (c) {
                mapController = c;
                setState(() => mapReady = true);
                if (!_didAutoLocate) {
                  _didAutoLocate = true;
                  _goMyLocation(silent: true);
                }
              },
              onCameraMove: (pos) => cameraTarget = pos.target,
              onTap: (p) => _applyMapPoint(p),
              onLongPress: (p) => _applyMapPoint(p),
              onPickupDragEnd: (p) =>
                  _applyMapPoint(p, force: PickTarget.pickup),
              onDropoffDragEnd: (p) =>
                  _applyMapPoint(p, force: PickTarget.dropoff),
            ),
          ),
          if (mapReady && !showSearchPanel)
            Align(
              alignment: const Alignment(0, -0.08),
              child: IgnorePointer(
                child: Icon(
                  Icons.location_on_rounded,
                  size: 40,
                  color: _activeColor,
                  shadows: const [
                    Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            top: topPad + 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: maxForest,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: maxShadowFloat,
                      ),
                      child: const Text(
                        'MaX Ride',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    MaxCircleIconButton(
                      icon: Icons.history_rounded,
                      tooltip: 'Trip history',
                      onTap: () => context.push('/history'),
                    ),
                    const SizedBox(width: 8),
                    MaxCircleIconButton(
                      icon: Icons.person_outline_rounded,
                      tooltip: 'Profile',
                      onTap: () => context.push('/profile'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MaxGlassCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  child: Column(
                    children: [
                      _WhereRow(
                        selected: activeTarget == PickTarget.pickup,
                        color: maxPickup,
                        icon: Icons.radio_button_checked,
                        label: 'Pickup',
                        value: pickup?['name']?.toString() ?? 'Current or search',
                        empty: pickup == null,
                        onTap: () => _openTarget(PickTarget.pickup),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 13),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 2,
                            height: 10,
                            color: maxLine,
                          ),
                        ),
                      ),
                      _WhereRow(
                        selected: activeTarget == PickTarget.dropoff,
                        color: maxDropoff,
                        icon: Icons.flag_rounded,
                        label: 'Drop-off',
                        value: dropoff?['name']?.toString() ?? 'Where to?',
                        empty: dropoff == null,
                        onTap: () => _openTarget(PickTarget.dropoff),
                      ),
                      if (showSearchPanel) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: searchCtrl,
                          focusNode: searchFocus,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: activeTarget == PickTarget.pickup
                                ? 'Search a pickup place'
                                : 'Search a drop-off place',
                            prefixIcon: Icon(Icons.search_rounded, color: _activeColor),
                            suffixIcon: searching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'Close search',
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      setState(() => showSearchPanel = false);
                                      searchFocus.unfocus();
                                    },
                                  ),
                          ),
                        ),
                        if (activeTarget == PickTarget.pickup)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: locating ? null : _useCurrentAsPickup,
                              icon: locating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.my_location_rounded, size: 18),
                              label: Text(
                                locating
                                    ? 'Getting your location…'
                                    : 'Use my current location',
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (showSearchPanel) ...[
                  const SizedBox(height: 8),
                  MaxGlassCard(
                    padding: EdgeInsets.zero,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    activeTarget == PickTarget.pickup
                                        ? 'Choose pickup'
                                        : 'Choose drop-off',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (searchProvider != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      searchProvider == 'GOOGLE_PLACES'
                                          ? 'Places'
                                          : 'Local',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: searchProvider == 'GOOGLE_PLACES'
                                            ? maxForest
                                            : maxMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (searchWarning != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Text(
                                searchWarning!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          Expanded(
                            child: searching
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : searchResults.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Text(
                                            'No places found. Try another name, or set the pin on the map.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: maxMuted,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        itemCount: searchResults.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 1, indent: 56),
                                        itemBuilder: (_, i) {
                                          final place = searchResults[i];
                                          return ListTile(
                                            leading: CircleAvatar(
                                              radius: 18,
                                              backgroundColor:
                                                  _activeColor.withValues(alpha: 0.12),
                                              child: Icon(
                                                Icons.place_rounded,
                                                size: 18,
                                                color: _activeColor,
                                              ),
                                            ),
                                            title: Text(
                                              place['name']?.toString() ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                            subtitle: Text(
                                              place['address']?.toString() ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            onTap: () => _selectPlace(place),
                                          );
                                        },
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!showSearchPanel)
            Positioned(
              right: 16,
              bottom: sheetMax + 72,
              child: MaxCircleIconButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Recenter map',
                onTap: _goMyLocation,
              ),
            ),
          if (!showSearchPanel)
            Positioned(
              left: 72,
              right: 72,
              bottom: sheetMax + 18,
              child: Center(
                child: Material(
                  color: _activeColor,
                  borderRadius: BorderRadius.circular(999),
                  elevation: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: loading ? null : _confirmCenterPin,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.push_pin_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _confirmLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!showSearchPanel)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: maxSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: maxShadowSoft,
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: sheetMax),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const MaxSheetHandle(),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 88,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, i) {
                              final c = categories[i] as Map;
                              final selected = c['id'] == selectedCategoryId;
                              final code = c['code']?.toString();
                              return Semantics(
                                button: true,
                                selected: selected,
                                label: '${c['name']}, ${c['capacity']} seats',
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() =>
                                        selectedCategoryId = c['id'] as String);
                                    _refreshEstimate();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 96,
                                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                                    decoration: BoxDecoration(
                                      color: selected ? maxForest : maxSand,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: selected
                                            ? maxForest
                                            : const Color(0x140B1F1A),
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          vehicleEmojiFor(code),
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        const Spacer(),
                                        Text(
                                          c['name']?.toString() ?? '',
                                          style: TextStyle(
                                            color: selected ? Colors.white : maxInk,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '${c['capacity']} seats',
                                          style: TextStyle(
                                            color: selected
                                                ? maxLime
                                                : maxMuted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _PayChip(
                                label: 'Cash',
                                selected: paymentMethod == 'CASH',
                                onTap: () =>
                                    setState(() => paymentMethod = 'CASH'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PayChip(
                                label: 'Card',
                                selected: paymentMethod == 'CARD',
                                onTap: () =>
                                    setState(() => paymentMethod = 'CARD'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () =>
                                  setState(() => promoOpen = !promoOpen),
                              child: Text(promoOpen || promo.isNotEmpty
                                  ? 'Promo'
                                  : 'Add promo'),
                            ),
                          ],
                        ),
                        if (promoOpen) ...[
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Promo code',
                              hintText: 'e.g. MAX10',
                              isDense: true,
                            ),
                            onChanged: (v) {
                              promo = v;
                              estimateDebounce?.cancel();
                              estimateDebounce = Timer(
                                const Duration(milliseconds: 450),
                                _refreshEstimate,
                              );
                            },
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            error!,
                            style: const TextStyle(
                              color: Color(0xFFB42318),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Semantics(
                          button: true,
                          enabled: canBook && !loading,
                          hint: canBook ? null : _ctaHint,
                          child: ElevatedButton(
                            onPressed: !canBook
                                ? null
                                : loading
                                    ? () {}
                                    : _requestRide,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(canBook ? 'Request ride' : _ctaHint),
                                      if (canBook &&
                                          (_fareLine != null || estimating))
                                        Text(
                                          estimating
                                              ? 'Updating fare…'
                                              : _fareLine!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white
                                                .withValues(alpha: 0.85),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhereRow extends StatelessWidget {
  const _WhereRow({
    required this.selected,
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    required this.empty,
    required this.onTap,
  });

  final bool selected;
  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected ? color : maxMuted,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: empty ? maxMuted : maxInk,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.search_rounded,
                size: 18,
                color: selected ? color : const Color(0x660B1F1A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayChip extends StatelessWidget {
  const _PayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0x1A0F3D2E) : maxSand,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? maxForest : const Color(0x140B1F1A),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, size: 16, color: maxForest),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? maxForest : maxInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
