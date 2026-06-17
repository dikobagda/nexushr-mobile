import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'api_service.dart';

class AttendanceLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int radius;
  final List<String> excludedEmployeeIds;

  AttendanceLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.excludedEmployeeIds,
  });

  factory AttendanceLocation.fromJson(Map<String, dynamic> json) {
    var rawExcluded = json['excluded_employee_ids'];
    List<String> excludedList = [];
    if (rawExcluded is List) {
      excludedList = rawExcluded.map((e) => e.toString()).toList();
    }
    return AttendanceLocation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      radius: int.tryParse(json['radius']?.toString() ?? '100') ?? 100,
      excludedEmployeeIds: excludedList,
    );
  }
}

class AttendanceService {
  Future<List<AttendanceLocation>> fetchLocations() async {
    try {
      final response = await ApiService.get('/attendance/live/locations');
      debugPrint(
        '[AttendanceService] fetchLocations status: ${response.statusCode}',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('[AttendanceService] fetchLocations count: ${data.length}');
        return data.map((json) => AttendanceLocation.fromJson(json)).toList();
      }
      debugPrint(
        '[AttendanceService] fetchLocations error body: ${response.body}',
      );
      return [];
    } catch (e) {
      debugPrint('[AttendanceService] fetchLocations exception: $e');
      return [];
    }
  }

  Future<List<dynamic>> fetchTodayLogs() async {
    try {
      final response = await ApiService.get('/attendance/live/logs/today');
      debugPrint(
        '[AttendanceService] fetchTodayLogs status: ${response.statusCode}',
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('[AttendanceService] fetchTodayLogs exception: $e');
      return [];
    }
  }

  Future<List<dynamic>> fetchMyLogs({String? startDate, String? endDate}) async {
    try {
      String query = '';
      if (startDate != null && endDate != null) {
        query = '?startDate=$startDate&endDate=$endDate';
      }
      final response = await ApiService.get('/attendance/my-logs$query');
      debugPrint(
        '[AttendanceService] fetchMyLogs status: ${response.statusCode}',
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('[AttendanceService] fetchMyLogs exception: $e');
      return [];
    }
  }

  Future<String?> clockIn({
    required String employeeId,
    required double latitude,
    required double longitude,
    required String address,
    String? note,
  }) async {
    try {
      final response = await ApiService.post('/attendance/live/clock-in', {
        'employeeId': employeeId,
        'type': 'in',
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'note': note ?? '',
      });

      if (response.statusCode == 201) {
        return null; // Success
      } else {
        final body = jsonDecode(response.body);
        return body['error'] ?? 'Clock in failed';
      }
    } catch (e) {
      return 'Network error occurred';
    }
  }

  Future<String?> clockOut({
    required String employeeId,
    required double latitude,
    required double longitude,
    required String address,
    String? note,
  }) async {
    try {
      final response = await ApiService.post('/attendance/live/clock-out', {
        'employeeId': employeeId,
        'type': 'out',
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'note': note ?? '',
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        return null; // Success
      } else {
        final body = jsonDecode(response.body);
        return body['error'] ?? 'Clock out failed';
      }
    } catch (e) {
      return 'Network error occurred';
    }
  }
}
