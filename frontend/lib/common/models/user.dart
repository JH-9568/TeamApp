class User {
  User({
    required this.id,
    required this.email,
    required this.name,
    this.avatar,
  });

  final String id;
  final String email;
  final String name;
  final String? avatar;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      if (avatar != null) 'avatar': avatar,
    };
  }
}
