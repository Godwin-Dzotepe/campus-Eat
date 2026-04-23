import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../providers/location_provider.dart';
import '../providers/address_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../models/address_model.dart';

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState
    extends ConsumerState<LocationPickerScreen> {
  static const _tomTomApiKey = 'JBHJkfd6og6LP8I9twlyFy5hQ1Q8vBTZ';
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  LatLng _center = const LatLng(6.5244, 3.3792); // Lagos default
  String _address = 'Move the map to select location';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(selectedAddressProvider);
    if (existing != null) {
      _center = LatLng(existing.lat, existing.lng);
      _address = existing.fullAddress;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _loading = true);
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    if (pos != null) {
      final lat = pos.latitude;
      final lng = pos.longitude;
      _center = LatLng(lat, lng);
      _mapController.move(_center, 16);
      _address = await LocationService.getAddressFromCoords(lat, lng);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get location')));
    }
    setState(() => _loading = false);
  }

  Future<void> _onMapMoved(MapCamera camera) async {
    _center = camera.center;
    _address = await LocationService.getAddressFromCoords(
        _center.latitude, _center.longitude);
    if (mounted) setState(() {});
  }

  void _confirm() {
    final selected = AddressModel(
      label: 'Selected Location',
      fullAddress: _address,
      lat: _center.latitude,
      lng: _center.longitude,
    );
    ref.read(selectedAddressProvider.notifier).state = selected;
    final user = ref.read(authProvider).valueOrNull;
    if (user != null) {
      AddressActions.saveAddress(userId: user.id, address: selected);
    }
    context.pop();
  }

  void _selectSaved(AddressModel address) {
    _center = LatLng(address.lat, address.lng);
    _mapController.move(_center, 16);
    _address = address.fullAddress;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savedAsync = ref.watch(savedAddressesProvider);
    final user = ref.watch(authProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Meet-up Location'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _onMapMoved(event.camera);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?key=$_tomTomApiKey',
                userAgentPackageName: 'com.campuseat.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.location_pin,
                      color: theme.colorScheme.primary,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Address bar at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(Icons.location_on_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _address,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // My location FAB
          Positioned(
            bottom: 120,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'location',
              onPressed: _loading ? null : _useMyLocation,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
            ),
          ),

          if (user != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 110,
              child: savedAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Saved addresses unavailable: ${e.toString()}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Card(
                    elevation: 4,
                    child: SizedBox(
                      height: 88,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return InkWell(
                            onTap: () => _selectSaved(item),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 220,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline,
                                            size: 16),
                                        onPressed: item.id == null
                                            ? null
                                            : () => AddressActions.deleteAddress(
                                                  userId: user.id,
                                                  addressId: item.id!,
                                                ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    item.fullAddress,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.black54),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: items.length,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Confirm button
          Positioned(
            bottom: 32,
            left: 20,
            right: 20,
                child: FilledButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Confirm Meet-up Location',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
