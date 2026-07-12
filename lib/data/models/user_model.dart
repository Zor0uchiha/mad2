class UserModel {
  String uid;
  String email;
  String? displayName;
  String? photoUrl;
  String? bio;
  DateTime? createdAt;
  bool isAnonymous;
  bool isPublicProfile;
  DateTime updatedAt;
  int booksRead;
  int readingStreak;

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
    this.booksRead = 0,
    this.readingStreak = 0,
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
    int? booksRead,
    int? readingStreak,
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
      booksRead: booksRead ?? this.booksRead,
      readingStreak: readingStreak ?? this.readingStreak,
    );
  }
}
