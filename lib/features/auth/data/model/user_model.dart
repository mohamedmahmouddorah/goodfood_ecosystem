import 'package:cloud_firestore/cloud_firestore.dart';

enum Role { Admin, Chef }

Role? toRole(String role) {
  for (var i in Role.values) {
    if (i.name == role) {
      return i;
    }
  }
  return null;
}

enum AccountStatus { Active, Inactive }

AccountStatus? toStatus(String status) {
  for (var i in AccountStatus.values) {
    if (i.name == status) {
      return i;
    }
  }
  return null;
}

class UserModel {
  String? uid;
  String name;
  String? imgUrl;
  String email;
  String? phone;
  Role role;
  AccountStatus status;
  DateTime startDate;
  UserModel({
    this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.imgUrl,
    required this.status,
    this.phone,
    required this.startDate,
  });
  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "email": email,
      "img_url": imgUrl,
      "phone": phone,
      "role": role.name,
      "status": status.name,
      "start_date": Timestamp.fromDate(startDate),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> data) {
    final tempRole = toRole(data["role"]);
    final tempStatus = toStatus(data["status"]);

    if (tempRole == null) {
      throw FormatException('Invalid role: ${data["role"]}');
    }

    if (tempStatus == null) {
      throw FormatException('Invalid status: ${data["status"]}');
    }

    return UserModel(
      uid: data["uid"],
      name: data["name"],
      email: data["email"],
      role: tempRole,
      status: tempStatus,
      startDate: (data["start_date"] as Timestamp).toDate(),
    );
  }
  UserModel copyWith({
  String? uid,
  String? name,
  String? imgUrl,
  String? email,
  String? phone,
  Role? role,
  AccountStatus? status,
  DateTime? startDate,
}) {
  return UserModel(
    uid: uid ?? this.uid,
    name: name ?? this.name,
    imgUrl: imgUrl ?? this.imgUrl,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    status: status ?? this.status,
    startDate: startDate ?? this.startDate,
  );
}
bool get isActive => status == AccountStatus.Active;
}
