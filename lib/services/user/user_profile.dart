/// A user's public profile, as stored in `users/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    this.name = '',
    this.username = '',
    this.photoUrl = '',
    this.email = '',
    this.dob = '',
    this.gender = '',
    this.nameLower = '',
    this.emailVerified = false,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) =>
      UserProfile(
        uid: uid,
        name: _string(data['name']).trim(),
        username: _string(data['username']),
        photoUrl: _string(data['profilePictureUrl']),
        email: _string(data['email']),
        dob: _string(data['dob']),
        gender: _string(data['gender']),
        nameLower: _string(data['nameLower']),
        emailVerified: data['emailVerified'] == true,
      );

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        uid: _string(json['uid']),
        name: _string(json['name']),
        username: _string(json['username']),
        photoUrl: _string(json['photoUrl']),
        email: _string(json['email']),
        dob: _string(json['dob']),
        gender: _string(json['gender']),
        nameLower: _string(json['nameLower']),
        emailVerified: json['emailVerified'] == true,
      );

  final String uid;
  final String name;

  /// Lowercase, starts with "@".
  final String username;
  final String photoUrl;
  final String email;
  final String dob;
  final String gender;

  /// Search key for name prefix search; missing on accounts created before
  /// search was indexed until their owner signs in again.
  final String nameLower;
  final bool emailVerified;

  String get displayName {
    if (name.isNotEmpty) return name;
    if (username.isNotEmpty) return username;
    return 'Unknown';
  }

  bool get hasUsername => username.length > 1;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'username': username,
        'photoUrl': photoUrl,
        'email': email,
        'dob': dob,
        'gender': gender,
        'nameLower': nameLower,
        'emailVerified': emailVerified,
      };

  /// Keeps the private fields of this profile but takes the public ones
  /// (which friends lists and chats carry for free) from [other].
  UserProfile withPublicFieldsOf(UserProfile other) => UserProfile(
        uid: uid,
        name: other.name.isNotEmpty ? other.name : name,
        username: other.username.isNotEmpty ? other.username : username,
        photoUrl: other.photoUrl.isNotEmpty ? other.photoUrl : photoUrl,
        email: email,
        dob: dob,
        gender: gender,
        nameLower: nameLower,
        emailVerified: emailVerified,
      );

  static String _string(Object? value) => value is String ? value : '';
}
