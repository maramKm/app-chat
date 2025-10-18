class User {
  final String id;
  final String name;
  final String email;
  final bool isOnline;
  final DateTime lastSeen;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.isOnline,
    required this.lastSeen,
  });
}