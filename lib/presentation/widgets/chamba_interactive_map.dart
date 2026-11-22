import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/worker_profile.dart';

enum MapDisplayMode {
  selectLocation, // Client selecting exact address & pin
  approximate,    // Worker previewing nearby job with privacy circle
  tracking,       // Live service tracking showing worker moving toward client
}

class ChambaInteractiveMap extends StatefulWidget {
  final MapDisplayMode mode;
  final LatLng initialCenter;
  final double initialZoom;
  final double height;
  final bool isInteractive;
  final Function(LatLng position, String districtName)? onLocationChanged;
  final LatLng? workerPosition;
  final String? clientAddress;
  final bool isSos;
  final List<WorkerProfile> nearbyWorkers;
  final Function(WorkerProfile worker)? onWorkerTap;

  const ChambaInteractiveMap({
    super.key,
    this.mode = MapDisplayMode.selectLocation,
    this.initialCenter = const LatLng(-6.7760, -79.8436), // Santa Victoria, Chiclayo
    this.initialZoom = 15.0,
    this.height = 240.0,
    this.isInteractive = true,
    this.onLocationChanged,
    this.workerPosition,
    this.clientAddress,
    this.isSos = false,
    this.nearbyWorkers = const [],
    this.onWorkerTap,
  });

  @override
  State<ChambaInteractiveMap> createState() => _ChambaInteractiveMapState();
}

class _ChambaInteractiveMapState extends State<ChambaInteractiveMap>
    with SingleTickerProviderStateMixin {
  late MapController _mapController;
  late LatLng _currentPin;
  late AnimationController _radarController;
  bool _isLoadingGps = false;

  // Well-known Chiclayo districts for fast selection
  static const Map<String, LatLng> chiclayoDistricts = {
    'Santa Victoria': LatLng(-6.7760, -79.8436),
    'Chiclayo Centro': LatLng(-6.7714, -79.8409),
    'La Victoria': LatLng(-6.7892, -79.8423),
    'J.L. Ortiz': LatLng(-6.7589, -79.8375),
    'Pimentel': LatLng(-6.8333, -79.9333),
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentPin = widget.initialCenter;
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _detectGpsLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        final detected = LatLng(position.latitude, position.longitude);
        _updatePin(detected, 'Ubicación actual GPS');
      } else {
        // Fallback gracefully
        _updatePin(chiclayoDistricts['Santa Victoria']!, 'Santa Victoria, Chiclayo');
      }
    } catch (_) {
      // Offline or emulator without GPS fix
      _updatePin(chiclayoDistricts['Santa Victoria']!, 'Santa Victoria, Chiclayo');
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  void _updatePin(LatLng pos, String name) {
    setState(() {
      _currentPin = pos;
    });
    _mapController.move(pos, 15.5);
    widget.onLocationChanged?.call(pos, name);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F173B4D), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A173B4D),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: widget.initialZoom,
              interactionOptions: InteractionOptions(
                flags: widget.isInteractive
                    ? (widget.mode == MapDisplayMode.tracking
                        ? (InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom)
                        : InteractiveFlag.all)
                    : InteractiveFlag.none,
              ),
              onTap: widget.mode == MapDisplayMode.selectLocation && widget.isInteractive
                  ? (tapPosition, point) {
                      _updatePin(point, 'Ubicación seleccionada');
                    }
                  : null,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'pe.chamba.app',
                maxZoom: 19,
              ),

              // Approximate Privacy Circle for Worker Mode
              if (widget.mode == MapDisplayMode.approximate)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: widget.initialCenter,
                      radius: 500, // 500m radius
                      useRadiusInMeter: true,
                      color: AppColors.secondary.withValues(alpha: 0.20),
                      borderColor: AppColors.secondary,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),

              // Tracking Polyline between worker and client
              if (widget.mode == MapDisplayMode.tracking && widget.workerPosition != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [widget.workerPosition!, widget.initialCenter],
                      strokeWidth: 4.0,
                      color: AppColors.secondary,
                    ),
                  ],
                ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // Client / Job Destination Pin
                  if (widget.mode != MapDisplayMode.approximate)
                    Marker(
                      point: _currentPin,
                      width: widget.isSos ? 84 : 44,
                      height: widget.isSos ? 84 : 44,
                      child: widget.isSos
                          ? AnimatedBuilder(
                              animation: _radarController,
                              builder: (context, _) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CustomPaint(
                                      size: const Size(84, 84),
                                      painter: _MapRadarPainter(_radarController.value),
                                    ),
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.sosRed,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2.5),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x66DC2626),
                                            blurRadius: 10,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.emergency_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x40000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.home_filled,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                    ),

                  // Worker Live Moving Marker
                  if (widget.mode == MapDisplayMode.tracking && widget.workerPosition != null)
                    Marker(
                      point: widget.workerPosition!,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.two_wheeler_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),

                  // Approximate Zone Center Pin
                  if (widget.mode == MapDisplayMode.approximate)
                    Marker(
                      point: widget.initialCenter,
                      width: 38,
                      height: 38,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                  // Nearby workers markers (PostGIS)
                  ...widget.nearbyWorkers
                      .where((w) => w.latitude != null && w.longitude != null)
                      .map(
                        (w) => Marker(
                          point: LatLng(w.latitude!, w.longitude!),
                          width: 52,
                          height: 52,
                          child: GestureDetector(
                            onTap: () => widget.onWorkerTap?.call(w),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      w.avatarInitials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                if (w.distanceKm != null)
                                  Positioned(
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${w.distanceKm!.toStringAsFixed(1)}k',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ],
          ),

          // Top Info Banner depending on mode
          if (widget.isSos)
            const PositionEdgeBanner(
              icon: Icons.emergency_rounded,
              label: '🚨 RADAR SOS ACTIVO • Atención prioritaria en camino (< 30 min)',
              color: AppColors.sosRed,
            )
          else if (widget.mode == MapDisplayMode.approximate)
            PositionEdgeBanner(
              icon: Icons.shield_outlined,
              label: 'Zona aproximada (Radio 500m) • Dirección exacta al ser contratado',
              color: AppColors.primary,
            )
          else if (widget.mode == MapDisplayMode.selectLocation)
            const PositionEdgeBanner(
              icon: Icons.touch_app_outlined,
              label: 'Toca el mapa o mueve el marcador para ajustar tu casa',
              color: AppColors.primary,
            )
          else if (widget.mode == MapDisplayMode.tracking)
            const PositionEdgeBanner(
              icon: Icons.directions_bike_rounded,
              label: 'Especialista en ruta en moto • Tiempo estimado 12 min',
              color: AppColors.tertiary,
            ),

          // GPS Button and District Quick-Pills for selectLocation mode
          if (widget.mode == MapDisplayMode.selectLocation && widget.isInteractive)
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'map_gps_btn',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 3,
                onPressed: _isLoadingGps ? null : _detectGpsLocation,
                child: _isLoadingGps
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.my_location, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapRadarPainter extends CustomPainter {
  final double progress;

  _MapRadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + (i * 0.33)) % 1.0;
      final radius = 22.0 + (maxRadius - 22.0) * waveProgress;
      final opacity = (1.0 - waveProgress).clamp(0.0, 1.0) * 0.5;

      final paint = Paint()
        ..color = AppColors.sosRed.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapRadarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}


class PositionEdgeBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const PositionEdgeBanner({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x20000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: AppTypography.labelSm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
