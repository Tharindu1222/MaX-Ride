import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
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
  Map<String, dynamic>? estimate;
  bool loading = false;
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

  String? searchProvider;
  String? searchWarning;
  bool locating = false;

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
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
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

  /// Resolve device GPS with timeouts + permission prompts (works on emulators with mock GPS).
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

    // Prefer last fix (fast on emulator after mock location is set)
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
    } catch (_) {}

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } on TimeoutException {
      _toast('GPS timeout — set a location on the emulator (⋯ → Location)');
      return null;
    } catch (e) {
      _toast('Could not get GPS: $e');
      return null;
    }
  }

  Future<void> _goMyLocation() async {
    setState(() => locating = true);
    final pos = await _resolveDevicePosition();
    if (!mounted) return;
    setState(() => locating = false);
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
    _toast('GPS unavailable — pickup set to map center. Set emulator GPS or pan the map.');
  }

  Future<void> _estimate() async {
    if (!canBook) return;
    setState(() {
      loading = true;
      error = null;
    });
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
      setState(() => estimate = Map<String, dynamic>.from(res['data'] as Map));
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
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

  Color get _activeColor => activeTarget == PickTarget.pickup
      ? const Color(0xFF2E7D32)
      : const Color(0xFFC62828);

  String get _confirmLabel => activeTarget == PickTarget.pickup
      ? 'Set pickup at map pin'
      : 'Set drop-off at map pin';

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // —— Map ——
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

          // Center crosshair pin
          if (mapReady && !showSearchPanel)
            Align(
              alignment: const Alignment(0, -0.12),
              child: IgnorePointer(
                child: Icon(Icons.location_on, size: 52, color: _activeColor),
              ),
            ),

          // —— Top: Pickup / Drop-off + Search ——
          Positioned(
            left: 12,
            right: 12,
            top: topPad + 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand + actions
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: maxForest,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Text(
                        'MaX Ride',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _roundIcon(Icons.history, () => context.push('/history')),
                    const SizedBox(width: 8),
                    _roundIcon(
                      Icons.person_outline,
                      () => context.push('/profile'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Location card: two big buttons + search
                Material(
                  color: Colors.white,
                  elevation: 6,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      children: [
                        // Pickup button
                        _LocationButton(
                          selected: activeTarget == PickTarget.pickup,
                          color: const Color(0xFF2E7D32),
                          icon: Icons.trip_origin,
                          title: 'Pickup location',
                          subtitle: pickup?['name']?.toString() ??
                              'Tap to search or set on map',
                          detail: pickup?['address']?.toString(),
                          onTap: () => _openTarget(PickTarget.pickup),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 18),
                          child: Row(
                            children: [
                              Container(
                                width: 2,
                                height: 14,
                                color: Colors.black12,
                              ),
                            ],
                          ),
                        ),
                        // Drop-off button
                        _LocationButton(
                          selected: activeTarget == PickTarget.dropoff,
                          color: const Color(0xFFC62828),
                          icon: Icons.flag,
                          title: 'Drop-off location',
                          subtitle: dropoff?['name']?.toString() ??
                              'Tap to search or set on map',
                          detail: dropoff?['address']?.toString(),
                          onTap: () => _openTarget(PickTarget.dropoff),
                        ),

                        const SizedBox(height: 12),

                        // Search field
                        TextField(
                          controller: searchCtrl,
                          focusNode: searchFocus,
                          onTap: () {
                            setState(() => showSearchPanel = true);
                            if (searchResults.isEmpty) _runSearch('');
                          },
                          onChanged: (v) {
                            setState(() => showSearchPanel = true);
                            _onSearchChanged(v);
                          },
                          decoration: InputDecoration(
                            hintText: activeTarget == PickTarget.pickup
                                ? 'Search pickup place…'
                                : 'Search drop-off place…',
                            prefixIcon: Icon(Icons.search, color: _activeColor),
                            suffixIcon: searching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : (searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          searchCtrl.clear();
                                          _runSearch('');
                                        },
                                      )
                                    : null),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: maxSand.withValues(alpha: 0.65),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        if (activeTarget == PickTarget.pickup) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: locating ? null : _useCurrentAsPickup,
                              icon: locating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location, size: 18),
                              label: Text(
                                locating
                                    ? 'Getting your location…'
                                    : 'Use my current location',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: maxForest,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Search results dropdown
                if (showSearchPanel) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.white,
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.34,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activeTarget == PickTarget.pickup
                                            ? 'Choose pickup'
                                            : 'Choose drop-off',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (searchProvider != null)
                                        Text(
                                          searchProvider == 'GOOGLE_PLACES'
                                              ? 'Google Places results'
                                              : 'Local suggestions',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: searchProvider ==
                                                    'GOOGLE_PLACES'
                                                ? maxForest
                                                : Colors.black45,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => showSearchPanel = false);
                                    searchFocus.unfocus();
                                  },
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                          if (searchWarning != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                              child: Text(
                                searchWarning!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          const Divider(height: 1),
                          Expanded(
                            child: searching
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : searchResults.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Text(
                                            'No places found for this search.\n'
                                            'Enable Places API for your key, or try another query.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.black54,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        itemCount: searchResults.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 1),
                                        itemBuilder: (_, i) {
                                          final place = searchResults[i];
                                          return ListTile(
                                            dense: true,
                                            leading: CircleAvatar(
                                              radius: 16,
                                              backgroundColor:
                                                  _activeColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              child: Icon(
                                                Icons.place,
                                                size: 18,
                                                color: _activeColor,
                                              ),
                                            ),
                                            title: Text(
                                              place['name']?.toString() ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            subtitle: Text(
                                              place['address']?.toString() ??
                                                  '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right,
                                              size: 20,
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

          // Confirm map pin + my location (when not searching)
          if (!showSearchPanel) ...[
            Positioned(
              left: 16,
              right: 16,
              bottom: 268,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: FloatingActionButton.small(
                      heroTag: 'loc',
                      backgroundColor: Colors.white,
                      onPressed: _goMyLocation,
                      child: const Icon(Icons.my_location, color: maxForest),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: _activeColor,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 4,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: loading ? null : _confirmCenterPin,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.push_pin, color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _confirmLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(Icons.check_circle_outline,
                                color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // —— Bottom booking sheet ——
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: maxSand,
              elevation: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Vehicle',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 84,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, i) {
                              final c = categories[i] as Map;
                              final selected = c['id'] == selectedCategoryId;
                              return GestureDetector(
                                onTap: () => setState(
                                  () => selectedCategoryId = c['id'] as String,
                                ),
                                child: Container(
                                  width: 110,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        selected ? maxForest : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c['name']?.toString() ?? '',
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : maxInk,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${c['capacity']} seats',
                                        style: TextStyle(
                                          color: selected
                                              ? maxLime
                                              : Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Cash (LKR)'),
                              selected: paymentMethod == 'CASH',
                              onSelected: (_) =>
                                  setState(() => paymentMethod = 'CASH'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Card'),
                              selected: paymentMethod == 'CARD',
                              onSelected: (_) =>
                                  setState(() => paymentMethod = 'CARD'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Promo code (e.g. MAX10)',
                            isDense: true,
                          ),
                          onChanged: (v) => promo = v,
                        ),
                        if (estimate != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Estimate: LKR ${estimate!['estimatedFare']}\n'
                              '${estimate!['estimatedDistanceMeters']} m · '
                              '${((estimate!['estimatedDurationSeconds'] as num) / 60).round()} min',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Text(error!,
                              style: const TextStyle(color: Colors.red)),
                        ],
                        if (!canBook) ...[
                          const SizedBox(height: 8),
                          Text(
                            pickup == null
                                ? 'Select a pickup location to continue'
                                : 'Select a drop-off location to continue',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: loading || !canBook
                                    ? null
                                    : _estimate,
                                child: const Text('Estimate'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: loading || !canBook
                                    ? null
                                    : _requestRide,
                                child: Text(loading ? '…' : 'Request ride'),
                              ),
                            ),
                          ],
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

  Widget _roundIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: maxInk),
        ),
      ),
    );
  }
}

class _LocationButton extends StatelessWidget {
  const _LocationButton({
    required this.selected,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.detail,
  });

  final bool selected;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.black12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected ? color : Colors.black54,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: subtitle.startsWith('Tap')
                            ? Colors.black38
                            : maxInk,
                      ),
                    ),
                    if (detail != null && detail!.isNotEmpty)
                      Text(
                        detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.search : Icons.chevron_right,
                color: selected ? color : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
