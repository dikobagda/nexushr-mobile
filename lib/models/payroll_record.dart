class AllowanceDetail {
  final String name;
  final double amount;

  AllowanceDetail({
    required this.name,
    required this.amount,
  });

  factory AllowanceDetail.fromJson(Map<String, dynamic> json) {
    return AllowanceDetail(
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
    };
  }
}

class PayrollRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final double basicSalary;
  final double allowances;
  final List<AllowanceDetail> allowanceDetails;
  final int absentDays;
  final double absentDeduction;
  final double bpjsHealth;
  final double bpjsKetenagakerjaan;
  final double pph21;
  final double netTakeHome;
  final String ptkpStatus;
  final String bankName;
  final String bankAccount;
  final int month;
  final int year;
  final String periodStatus;
  final String startDate;
  final String endDate;

  PayrollRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.basicSalary,
    required this.allowances,
    required this.allowanceDetails,
    required this.absentDays,
    required this.absentDeduction,
    required this.bpjsHealth,
    required this.bpjsKetenagakerjaan,
    required this.pph21,
    required this.netTakeHome,
    required this.ptkpStatus,
    required this.bankName,
    required this.bankAccount,
    required this.month,
    required this.year,
    required this.periodStatus,
    required this.startDate,
    required this.endDate,
  });

  factory PayrollRecord.fromJson(Map<String, dynamic> json) {
    var allowanceList = <AllowanceDetail>[];
    if (json['allowanceDetails'] != null) {
      final List<dynamic> list = json['allowanceDetails'];
      allowanceList = list.map((item) => AllowanceDetail.fromJson(item)).toList();
    }

    return PayrollRecord(
      id: json['id'] ?? '',
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      basicSalary: (json['basicSalary'] ?? 0.0).toDouble(),
      allowances: (json['allowances'] ?? 0.0).toDouble(),
      allowanceDetails: allowanceList,
      absentDays: json['absentDays'] ?? 0,
      absentDeduction: (json['absentDeduction'] ?? 0.0).toDouble(),
      bpjsHealth: (json['bpjsKesehatan'] ?? 0.0).toDouble(),
      bpjsKetenagakerjaan: (json['bpjsKetenagakerjaan'] ?? 0.0).toDouble(),
      pph21: (json['pph21'] ?? 0.0).toDouble(),
      netTakeHome: (json['netTakeHome'] ?? 0.0).toDouble(),
      ptkpStatus: json['ptkpStatus'] ?? '',
      bankName: json['bankName'] ?? '',
      bankAccount: json['bankAccount'] ?? '',
      month: json['month'] ?? 1,
      year: json['year'] ?? 2026,
      periodStatus: json['periodStatus'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'basicSalary': basicSalary,
      'allowances': allowances,
      'allowanceDetails': allowanceDetails.map((item) => item.toJson()).toList(),
      'absentDays': absentDays,
      'absentDeduction': absentDeduction,
      'bpjsKesehatan': bpjsHealth,
      'bpjsKetenagakerjaan': bpjsKetenagakerjaan,
      'pph21': pph21,
      'netTakeHome': netTakeHome,
      'ptkpStatus': ptkpStatus,
      'bankName': bankName,
      'bankAccount': bankAccount,
      'month': month,
      'year': year,
      'periodStatus': periodStatus,
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}
