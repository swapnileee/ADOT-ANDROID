class StaffModel {
  final dynamic id;
  final String name;
  final String designation;
  final String phone;
  final DateTime joinDate;
  final double monthlySalary;
  final String status;
  final DateTime? createdAt;

  StaffModel({
    this.id,
    required this.name,
    required this.designation,
    required this.phone,
    required this.joinDate,
    required this.monthlySalary,
    this.status = 'active',
    this.createdAt,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'],
      name: json['name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? 'Salesman',
      phone: json['phone']?.toString() ?? '',
      joinDate: json['join_date'] != null
          ? DateTime.tryParse(json['join_date'].toString()) ?? DateTime.now()
          : (json['joinDate'] != null ? DateTime.tryParse(json['joinDate'].toString()) ?? DateTime.now() : DateTime.now()),
      monthlySalary: (json['monthly_salary'] as num?)?.toDouble() ?? (json['monthlySalary'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'designation': designation,
      'phone': phone,
      'join_date': joinDate.toIso8601String(),
      'monthly_salary': monthlySalary,
      'status': status,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
    if (id != null) {
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
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
