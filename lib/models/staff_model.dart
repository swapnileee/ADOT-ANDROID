class StaffModel {
  final dynamic id;
  final String name;
  final String designation;
  final String phone;
  final DateTime joinDate;
  final double monthlySalary;
  final double pendingSalary;
  final String status;
  final DateTime? createdAt;

  StaffModel({
    this.id,
    required this.name,
    required this.designation,
    required this.phone,
    required this.joinDate,
    required this.monthlySalary,
    this.pendingSalary = 0.0,
    this.status = 'active',
    this.createdAt,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedJoinDate;
    final rawJoin = json['joining_date'] ??
        json['join_date'] ??
        json['joinDate'] ??
        json['created_at'] ??
        json['createdAt'];
    if (rawJoin != null && rawJoin.toString().trim().isNotEmpty) {
      parsedJoinDate = DateTime.tryParse(rawJoin.toString())?.toLocal() ?? DateTime.now();
    } else {
      parsedJoinDate = DateTime.now();
    }

    return StaffModel(
      id: json['id'],
      name: json['name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? json['role']?.toString() ?? 'Salesman',
      phone: json['phone']?.toString() ?? '',
      joinDate: parsedJoinDate,
      monthlySalary: (json['monthly_salary'] as num?)?.toDouble() ??
          (json['monthlySalary'] as num?)?.toDouble() ??
          (json['base_salary'] as num?)?.toDouble() ??
          0.0,
      pendingSalary: (json['pending_salary'] as num?)?.toDouble() ??
          (json['pendingSalary'] as num?)?.toDouble() ??
          0.0,
      status: json['status']?.toString() ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString())?.toLocal() : null),
    );
  }

  Map<String, dynamic> toJson() {
    final formattedDate =
        '${joinDate.year.toString().padLeft(4, '0')}-${joinDate.month.toString().padLeft(2, '0')}-${joinDate.day.toString().padLeft(2, '0')}';
    final Map<String, dynamic> data = {
      'name': name,
      'designation': designation,
      'role': designation,
      'phone': phone,
      'joining_date': formattedDate,
      'join_date': joinDate.toUtc().toIso8601String(),
      'monthly_salary': monthlySalary,
      'base_salary': monthlySalary,
      'pending_salary': pendingSalary,
      'status': status,
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
    if (id != null) {
      data['id'] = id;
    }
    return data;
  }

  Map<String, dynamic> toEmployeeJson() {
    final formattedDate =
        '${joinDate.year.toString().padLeft(4, '0')}-${joinDate.month.toString().padLeft(2, '0')}-${joinDate.day.toString().padLeft(2, '0')}';
    final Map<String, dynamic> data = {
      'name': name,
      'phone': phone,
      'designation': designation,
      'role': designation,
      'joining_date': formattedDate,
      'join_date': joinDate.toUtc().toIso8601String(),
      'base_salary': monthlySalary,
      'pending_salary': pendingSalary > 0 ? pendingSalary : monthlySalary,
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
    if (id != null && id != '' && !id.toString().startsWith('st_')) {
      data['id'] = id;
    }
    return data;
  }

  StaffModel copyWith({
    dynamic id,
    String? name,
    String? designation,
    String? phone,
    DateTime? joinDate,
    double? monthlySalary,
    double? pendingSalary,
    String? status,
    DateTime? createdAt,
  }) {
    return StaffModel(
      id: id ?? this.id,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      phone: phone ?? this.phone,
      joinDate: joinDate ?? this.joinDate,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      pendingSalary: pendingSalary ?? this.pendingSalary,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
