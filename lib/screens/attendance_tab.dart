import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AttendanceTab extends StatefulWidget {
  const AttendanceTab({super.key});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab>
    with SingleTickerProviderStateMixin {
  final AttendanceService _attendanceService = AttendanceService();
  bool _isLoading = false;
  bool _showSuccess = false;
  String _successMessage = '';

  Position? _currentPosition;
  String _currentAddress = 'Fetching location...';
  List<AttendanceLocation> _authorizedLocations = [];
  AttendanceLocation? _nearestLocation;
  double _distanceToNearest = double.infinity;

  late AnimationController _clockController;
  String _currentTime = '';
  String _currentDate = '';

  String _attendanceStatus = 'idle'; // 'idle', 'clocked-in', 'clocked-out'
  String? _lastClockInTime;

  @override
  void initState() {
    super.initState();
    _clockController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _updateClock();
    _initAttendance();
  }

  void _updateClock() {
    final now = DateTime.now();
    final newTime = DateFormat('HH:mm').format(now);
    final newDate = DateFormat('EEEE, d MMMM yyyy').format(now);

    if (_currentTime != newTime || _currentDate != newDate) {
      if (mounted) {
        setState(() {
          _currentTime = newTime;
          _currentDate = newDate;
        });
      }
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _updateClock();
    });
  }

  @override
  void dispose() {
    _clockController.dispose();
    super.dispose();
  }

  Future<void> _initAttendance() async {
    setState(() => _isLoading = true);
    _authorizedLocations = await _attendanceService.fetchLocations();
    await _getCurrentLocation();
    await _fetchTodayStatus();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchTodayStatus() async {
    try {
      final logs = await _attendanceService.fetchTodayLogs();
      if (mounted) {
        setState(() {
          if (logs.isNotEmpty) {
            final lastLog = logs.last;
            final type = (lastLog['type'] ?? lastLog['Type'] ?? '').toString().toLowerCase();
            final timestampStr = lastLog['timestamp'] ?? lastLog['Timestamp'];
            if (type == 'in') {
              _attendanceStatus = 'clocked-in';
              if (timestampStr != null) {
                try {
                  final parsedTime = DateTime.parse(timestampStr.toString()).toLocal();
                  _lastClockInTime = DateFormat('HH:mm').format(parsedTime);
                } catch (_) {
                  _lastClockInTime = null;
                }
              }
            } else if (type == 'out') {
              _attendanceStatus = 'clocked-out';
            }
          } else {
            _attendanceStatus = 'idle';
            _lastClockInTime = null;
          }
        });
      }
    } catch (e) {
      print('[AttendanceTab] Error fetching today status: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) {
        _mockDebugLocation();
        return;
      }
      setState(() => _currentAddress = 'Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          _mockDebugLocation();
          return;
        }
        setState(() => _currentAddress = 'Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        _mockDebugLocation();
        return;
      }
      setState(
        () => _currentAddress = 'Location permissions permanently denied',
      );
      return;
    }

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        // Try last known position
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          if (kDebugMode) {
            _mockDebugLocation();
            return;
          } else {
            rethrow;
          }
        }
      }

      _currentPosition = position;

      if (kIsWeb) {
        await _reverseGeocodeWeb(position.latitude, position.longitude);
      } else {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks[0];
            setState(() {
              _currentAddress =
                  '${place.street}, ${place.subLocality}, ${place.locality}';
            });
          }
        } catch (_) {
          await _reverseGeocodeWeb(position.latitude, position.longitude);
        }
      }

      _calculateNearestLocation(position);
    } catch (e) {
      if (kDebugMode) {
        _mockDebugLocation();
      } else {
        setState(() => _currentAddress = 'Could not fetch location: $e');
      }
    }
  }

  void _mockDebugLocation() {
    final mockPos = Position(
      latitude: -6.1969,
      longitude: 106.8227,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
    _currentPosition = mockPos;
    setState(() {
      _currentAddress = 'Menara BCA, Grand Indonesia (Mocked Debug Location)';
    });
    _calculateNearestLocation(mockPos);
  }

  Future<void> _reverseGeocodeWeb(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
      );
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'HRIS-Pro-ESS/1.0',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'] as String? ?? '';
        final parts = displayName
            .split(',')
            .take(3)
            .map((s) => s.trim())
            .join(', ');
        setState(
          () => _currentAddress = parts.isNotEmpty ? parts : displayName,
        );
      } else {
        setState(
          () => _currentAddress =
              '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
        );
      }
    } catch (_) {
      setState(
        () => _currentAddress =
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
      );
    }
  }

  void _calculateNearestLocation(Position position) {
    if (_authorizedLocations.isEmpty) return;
    double minDistance = double.infinity;
    AttendanceLocation? nearest;

    for (var loc in _authorizedLocations) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        loc.latitude,
        loc.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = loc;
      }
    }

    setState(() {
      _nearestLocation = nearest;
      _distanceToNearest = minDistance;
    });
  }

  Future<void> _handleClockInOut(bool isClockIn) async {
    if (_currentPosition == null) {
      _showSnack('Wait for location to be fetched.', isError: true);
      return;
    }

    final user = context.read<AuthService>().currentUser;
    final isExcluded = _nearestLocation != null && user != null && _nearestLocation!.excludedEmployeeIds.contains(user.id);

    if (_nearestLocation != null &&
        _distanceToNearest > _nearestLocation!.radius &&
        !isExcluded) {
      _showSnack('You are outside the authorized radius!', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    if (user == null) return;

    String? error;
    if (isClockIn) {
      error = await _attendanceService.clockIn(
        employeeId: user.id,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: _currentAddress,
      );
    } else {
      error = await _attendanceService.clockOut(
        employeeId: user.id,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: _currentAddress,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      await _fetchTodayStatus();
      setState(() {
        _showSuccess = true;
        _successMessage = 'Successfully Clocked ${isClockIn ? 'In' : 'Out'}!';
      });
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted) setState(() => _showSuccess = false);
    } else {
      _showSnack(error, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser;
    final isExcluded = _nearestLocation != null && user != null && _nearestLocation!.excludedEmployeeIds.contains(user.id);
    final isWithinRadius =
        _nearestLocation != null &&
        (_distanceToNearest <= _nearestLocation!.radius || isExcluded);
    final progressValue = _nearestLocation != null
        ? (_distanceToNearest / (_nearestLocation!.radius * 2)).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Live Attendance',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _initAttendance,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Lottie.asset(
                      'assets/animations/location.json',
                      repeat: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fetching your location...',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  children: [
                    // Time Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 36,
                        horizontal: 28,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: Text(
                              _currentTime,
                              key: ValueKey(_currentTime),
                              style: GoogleFonts.inter(
                                fontSize: 72,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentDate,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.75),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'Live',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 400.ms).slideY(begin: -0.05),

                    const SizedBox(height: 20),

                    // Location Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current Location',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _currentAddress,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_currentAddress.contains('denied') || _currentAddress.contains('disabled'))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: InkWell(
                                          onTap: () async {
                                            if (_currentAddress.contains('disabled')) {
                                              await Geolocator.openLocationSettings();
                                            } else {
                                              await Geolocator.openAppSettings();
                                            }
                                          },
                                          child: Text(
                                            'Open Settings to Fix',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (_nearestLocation != null) ...[
                            const SizedBox(height: 20),
                            const Divider(height: 1),
                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Nearest Authorized Area',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    Text(
                                      _nearestLocation!.name,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                StatusBadge(
                                  label: isWithinRadius
                                      ? (isExcluded ? '✓ Bypassed' : '✓ In Range')
                                      : '✗ Out of Bounds',
                                  color: isWithinRadius
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Ring progress
                            _RadiusRing(
                              progress: progressValue,
                              isWithinRadius: isWithinRadius,
                              distanceM: _distanceToNearest,
                              radiusM: _nearestLocation!.radius.toDouble(),
                              isExcluded: isExcluded,
                            ),
                          ] else ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: AppColors.warning,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _authorizedLocations.isEmpty
                                          ? 'No authorized locations configured.'
                                          : 'GPS signal weak or location unavailable. Tap refresh.',
                                      style: GoogleFonts.inter(
                                        color: AppColors.warning,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ).animate(delay: 100.ms).fade().slideY(begin: 0.05),

                    const SizedBox(height: 24),

                    // Action Buttons
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        key: ValueKey(_attendanceStatus),
                        children: [
                          if (_attendanceStatus == 'idle')
                            GradientButton(
                              label: 'Clock In Now',
                              icon: Icons.login_rounded,
                              gradient: AppColors.successGradient,
                              onPressed: () => _handleClockInOut(true),
                            ),
                          if (_attendanceStatus == 'clocked-in') ...[
                            if (_lastClockInTime != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.success.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Checked In at $_lastClockInTime',
                                      style: GoogleFonts.inter(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            GradientButton(
                              label: 'Clock Out Now',
                              icon: Icons.logout_rounded,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                              ),
                              onPressed: () => _handleClockInOut(false),
                            ),
                          ],
                          if (_attendanceStatus == 'clocked-out')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.textMuted.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: AppColors.textMuted, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Shift Completed for Today',
                                    style: GoogleFonts.inter(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ).animate(delay: 200.ms).fade().slideY(begin: 0.1),
                  ],
                ),

                // Success overlay
                if (_showSuccess)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          margin: const EdgeInsets.symmetric(horizontal: 48),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: Lottie.asset(
                                  'assets/animations/success.json',
                                  repeat: false,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _successMessage,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fade(duration: 300.ms),
                  ),
              ],
            ),
    );
  }
}

class _RadiusRing extends StatelessWidget {
  final double progress;
  final bool isWithinRadius;
  final double distanceM;
  final double radiusM;
  final bool isExcluded;

  const _RadiusRing({
    required this.progress,
    required this.isWithinRadius,
    required this.distanceM,
    required this.radiusM,
    this.isExcluded = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWithinRadius ? AppColors.success : AppColors.error;
    return Column(
      children: [
        SizedBox(
          height: 14,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: LinearProgressIndicator(
              value: isExcluded ? 1.0 : progress,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isExcluded ? 'Radius Excluded' : '${distanceM.toStringAsFixed(0)}m away',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            Text(
              isExcluded ? 'Bypassed' : 'Max ${radiusM.toStringAsFixed(0)}m',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
