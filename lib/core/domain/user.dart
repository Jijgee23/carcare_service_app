import 'package:hive/hive.dart';

class UserRole {
  final String id;
  final String name;
  final List<String> permissions;
  UserRole(this.id, this.name, this.permissions);
}

class UserTenant {
  final String id;
  final String name;
  UserTenant(this.id, this.name);
}

class User extends HiveObject {
  String accessToken;
  String refreshToken;
  String id;
  String email;
  String firstName;
  String lastName;
  String phone;
  bool isOwner;
  String? branchId;
  UserRole? role;
  UserTenant tenant;

  User({
    required this.accessToken,
    required this.refreshToken,
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.isOwner,
    this.branchId,
    this.role,
    required this.tenant,
  });

  String get fullName => '$firstName $lastName';
}

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 0;

  @override
  User read(BinaryReader reader) {
    final accessToken = reader.readString();
    final refreshToken = reader.readString();
    final id = reader.readString();
    final email = reader.readString();
    final firstName = reader.readString();
    final lastName = reader.readString();
    final phone = reader.readString();
    final isOwner = reader.readBool();
    final branchId = reader.readString();
    final hasRole = reader.readBool();
    UserRole? role;
    if (hasRole) {
      role = UserRole(
        reader.readString(),
        reader.readString(),
        List<String>.from(reader.readList()),
      );
    }
    final tenant = UserTenant(reader.readString(), reader.readString());
    return User(
      accessToken: accessToken,
      refreshToken: refreshToken,
      id: id,
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      isOwner: isOwner,
      branchId: branchId.isEmpty ? null : branchId,
      role: role,
      tenant: tenant,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer.writeString(obj.accessToken);
    writer.writeString(obj.refreshToken);
    writer.writeString(obj.id);
    writer.writeString(obj.email);
    writer.writeString(obj.firstName);
    writer.writeString(obj.lastName);
    writer.writeString(obj.phone);
    writer.writeBool(obj.isOwner);
    writer.writeString(obj.branchId ?? '');
    writer.writeBool(obj.role != null);
    if (obj.role != null) {
      writer.writeString(obj.role!.id);
      writer.writeString(obj.role!.name);
      writer.writeList(obj.role!.permissions);
    }
    writer.writeString(obj.tenant.id);
    writer.writeString(obj.tenant.name);
  }
}
