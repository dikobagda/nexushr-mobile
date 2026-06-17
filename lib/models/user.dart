class User {
  final String id;
  final String name;
  final String email;
  final String? branchId;
  final String? role;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.branchId,
    this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      branchId: json['branch_id'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'branch_id': branchId,
      'role': role,
    };
  }
}
