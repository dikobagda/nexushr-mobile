import 'dart:convert';
import '../models/leave.dart';
import 'api_service.dart';

class LeaveService {
  Future<List<LeaveBalance>> fetchBalances(String employeeId, int year) async {
    try {
      final response = await ApiService.get(
        '/leave/balances/$employeeId/$year',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => LeaveBalance.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<LeaveRequest>> fetchRequests(String employeeId) async {
    try {
      final response = await ApiService.get(
        '/leave/requests/employee/$employeeId',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => LeaveRequest.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<LeaveType>> fetchLeaveTypes() async {
    try {
      final response = await ApiService.get('/leave/types');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => LeaveType.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<String?> submitRequest({
    required String employeeId,
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    required double totalDays,
    required String reason,
  }) async {
    try {
      final response = await ApiService.post('/leave/requests', {
        'employeeId': employeeId,
        'leaveTypeId': leaveTypeId,
        'startDate': startDate.toUtc().toIso8601String(),
        'endDate': endDate.toUtc().toIso8601String(),
        'totalDays': totalDays,
        'reason': reason,
      });

      if (response.statusCode == 201) {
        return null; // Success
      } else {
        final body = json.decode(response.body);
        return body['error'] ?? 'Failed to submit request';
      }
    } catch (e) {
      return 'Network error occurred';
    }
  }
}
