class Level {
  final String id, name;
  Level({required this.id, required this.name});

  factory Level.fromJson(Map<String, dynamic> json) => Level(
    id: json['_id']['\$oid'],
    name: json['name'] ?? '',
  );
}