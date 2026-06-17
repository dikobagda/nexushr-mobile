import 'dart:convert';
import '../models/payroll_record.dart';
import 'api_service.dart';

class PayrollService {
  Future<List<PayrollRecord>> fetchMyRecords() async {
    try {
      final response = await ApiService.get('/payroll/my-records');
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> data = body['data'] ?? [];
        return data.map((json) => PayrollRecord.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
