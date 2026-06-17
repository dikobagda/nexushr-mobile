class LeaveType {
  final String id;
  final String name;
  final String code;
  final int daysPerYear;

  LeaveType({
    required this.id,
    required this.name,
    required this.code,
    required this.daysPerYear,
  });

  factory LeaveType.fromJson(Map<String, dynamic> json) {
    return LeaveType(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      daysPerYear: json['daysPerYear'] ?? 0,
    );
  }
}

class LeaveBalance {
  final String id;
  final String employeeId;
  final String leaveTypeId;
  final int year;
  final double totalDays;
  final double usedDays;
  final double remainingDays;
  final LeaveType? leaveType;

  LeaveBalance({
    required this.id,
    required this.employeeId,
    required this.leaveTypeId,
    required this.year,
    required this.totalDays,
    required this.usedDays,
    required this.remainingDays,
    this.leaveType,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      id: json['id'],
      employeeId: json['employeeId'],
      leaveTypeId: json['leaveTypeId'],
      year: json['year'],
      totalDays: (json['totalDays'] ?? 0.0).toDouble(),
      usedDays: (json['usedDays'] ?? 0.0).toDouble(),
      remainingDays: (json['remainingDays'] ?? 0.0).toDouble(),
      leaveType: json['leaveType'] != null
          ? LeaveType.fromJson(json['leaveType'])
          : null,
    );
  }
}

class LeaveRequest {
  final String id;
  final String employeeId;
  final String leaveTypeId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalDays;
  final String reason;
  final String status;
  final LeaveType? leaveType;

  LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.leaveTypeId,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    required this.status,
    this.leaveType,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'],
      employeeId: json['employeeId'],
      leaveTypeId: json['leaveTypeId'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      totalDays: (json['totalDays'] ?? 0.0).toDouble(),
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'pending',
      leaveType: json['leaveType'] != null
          ? LeaveType.fromJson(json['leaveType'])
          : null,
    );
  }
}
