part of "user_model.dart";

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override final int typeId = 3;

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return UserModel(
      uid: fields[0] as String,
      email: fields[1] as String,
      displayName: fields[2] as String?,
      photoUrl: fields[3] as String?,
      bio: fields[4] as String?,
      createdAt: fields[5] as DateTime?,
      isAnonymous: (fields[6] as bool?) ?? false,
      isPublicProfile: (fields[7] as bool?) ?? true,
      updatedAt: fields[8] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.photoUrl)
      ..writeByte(4)
      ..write(obj.bio)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.isAnonymous)
      ..writeByte(7)
      ..write(obj.isPublicProfile)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }
}
