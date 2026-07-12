import "package:hive/hive.dart";

part "user_model.g.dart";

@HiveType(typeId: 3)
class UserModel extends HiveObject {
  @HiveField(0)
  String uid;

  @HiveField(1)
  String email;

  @HiveField(2)
  String? displayName;

  @HiveField(3)
  String? photoUrl;

  @HiveField(4)
  String? bio;

  @HiveField(5)
  DateTime? createdAt;

  @HiveField(6)
  bool isAnonymous;

  @HiveField(7)
  bool isPublicProfile;

  @HiveField(8)
  DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.bio,
    this.createdAt,
    this.isAnonymous = false,
    this.isPublicProfile = true,
    required this.updatedAt,
  });

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? bio,
    DateTime? createdAt,
    bool? isAnonymous,
    bool? isPublicProfile,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
