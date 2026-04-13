import 'package:flutter/material.dart';
import 'dart:async';
import '../models/announcement_model.dart';
import '../services/announcement_service.dart';
import '../services/inbox_service.dart';
import '../models/user_model.dart';
import 'home_screen.dart';

class MessagesScreen extends StatefulWidget {
  final UserModel user;

  const MessagesScreen({super.key, required this.user});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<List<Announcement>> _announcementsFuture;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _announcementsFuture = _loadAnnouncements();

    // 🔥 AUTO REFRESH (no UI change)
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {
          _announcementsFuture = _loadAnnouncements();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<List<Announcement>> _loadAnnouncements() async {
    final announcements = await AnnouncementService.fetchAnnouncements(
      widget.user.id!,
    );

    final seenIds = await InboxService.fetchSeenAnnouncementIds(
      widget.user.id!,
    );

    for (var a in announcements) {
      a.isSeen = seenIds.contains(a.id);
    }

    // 🔴 remove red dot when opened
    hasNewMessages.value = false;

    return announcements;
  }

  Future<void> _refresh() async {
    setState(() {
      _announcementsFuture = _loadAnnouncements();
    });
  }

  String formatTimeAgo(DateTime createdAt) {
    final localTime = createdAt.toLocal();
    final diff = DateTime.now().difference(localTime);

    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} minutes ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";
    if (diff.inDays == 1) return "1 day ago";
    return "${diff.inDays} days ago";
  }

  Widget buildCard(Announcement a) {
    final createdAt = DateTime.parse(a.createdAt).toLocal();
    final timeAgo = formatTimeAgo(createdAt);

    final isUnread = a.isSeen == false;

    return GestureDetector(
      onTap: () async {
        // 🔥 mark as read in backend
        await InboxService.markAsSeen(a.id, widget.user.id!);

        // 🔥 update UI instantly
        setState(() {
          a.isSeen = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFD6DDF5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              offset: const Offset(0, 4),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isUnread ? Colors.black : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              a.message,
              style: TextStyle(
                color: isUnread ? Colors.black87 : Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeAgo,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(user: widget.user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        goHome();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Messages", style: TextStyle(color: Colors.black)),
          centerTitle: false,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: goHome,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FutureBuilder<List<Announcement>>(
            future: _announcementsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final announcements = snapshot.data ?? [];

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: announcements.map(buildCard).toList(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
