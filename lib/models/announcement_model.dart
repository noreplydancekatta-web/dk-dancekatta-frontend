class Announcement {
  final String id;
  final String title;
  final String message;
  final String createdAt;
  bool isSeen;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isSeen = false,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['_id']?.toString() ?? '', // safely handle ID
      title: json['title'] ?? 'No Title',
      message: json['message'] ?? 'No Message',
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      isSeen: false,
    );
  }
}