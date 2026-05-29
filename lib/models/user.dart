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
  String branchId;
  UserRole role;
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
    required this.branchId,
    required this.role,
    required this.tenant,
  });

  String get fullName => '$firstName $lastName';
}

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 0;

  @override
  User read(BinaryReader reader) {
    return User(
      accessToken: reader.readString(),
      refreshToken: reader.readString(),
      id: reader.readString(),
      email: reader.readString(),
      firstName: reader.readString(),
      lastName: reader.readString(),
      phone: reader.readString(),
      isOwner: reader.readBool(),
      branchId: reader.readString(),
      role: UserRole(
        reader.readString(),
        reader.readString(),
        List<String>.from(reader.readList()),
      ),
      tenant: UserTenant(
        reader.readString(),
        reader.readString(),
      ),
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
    writer.writeString(obj.branchId);
    writer.writeString(obj.role.id);
    writer.writeString(obj.role.name);
    writer.writeList(obj.role.permissions);
    writer.writeString(obj.tenant.id);
    writer.writeString(obj.tenant.name);
  }
}
