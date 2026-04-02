import 'package:flutter/material.dart';
import '../models/announcement_model.dart';
import '../services/announcement_service.dart';
import '../services/inbox_service.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'dart:async';

class MessagesScreen extends StatefulWidget {
  final UserModel user;

  const MessagesScreen({super.key, required this.user});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<List<Announcement>> _announcementsFuture;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _announcementsFuture = _loadAnnouncements();

    // Auto refresh every 30 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _announcementsFuture = _loadAnnouncements();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch whenever this tab is revisited (triggered by HomeScreen rebuilding tabs)
    setState(() {
      _announcementsFuture = _loadAnnouncements();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<List<Announcement>> _loadAnnouncements() async {
    try {
      // Fetch announcements — if this fails, propagate the error
      final announcements =
          await AnnouncementService.fetchAnnouncements(widget.user.id!);

      // Fetch seen IDs separately — if this fails, just treat all as unseen
      List<String> seenIds = [];
      try {
        seenIds = await InboxService.fetchSeenAnnouncementIds(widget.user.id!);
      } catch (e) {
        debugPrint("Warning: Could not fetch seen IDs, treating all as unseen: $e");
      }

      for (var a in announcements) {
        a.isSeen = seenIds.contains(a.id);
      }

      // Mark unseen announcements as seen in background
      Future.delayed(Duration.zero, () async {
        for (var a in announcements) {
          if (!a.isSeen) {
            try {
              await InboxService.markAsSeen(widget.user.id!, a.id);
              debugPrint("Marked as seen: ${a.id}");
            } catch (e) {
              debugPrint("Warning: Could not mark as seen: ${a.id} - $e");
            }
          }
        }
        hasNewMessages.value = false;
      });

      return announcements;
    } catch (e) {
      debugPrint("Error loading announcements: $e");
      return [];
    }
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

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: a.isSeen ? Colors.white : const Color(0xFFBFCEFF),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(a.message),
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
    );
  }

  void goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        goHome(); // mobile back button
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            "Messages",
            style: TextStyle(color: Colors.black),
          ),
          centerTitle: false,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: goHome, // arrow back button
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

              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              final announcements = snapshot.data ?? [];

              if (announcements.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 200),
                      Center(
                        child: Text(
                          "No announcements available",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final now = DateTime.now();

              final today = announcements.where((a) {
                final created = DateTime.parse(a.createdAt).toLocal();
                return now.difference(created).inHours < 24;
              }).toList();

              final older = announcements.where((a) {
                final created = DateTime.parse(a.createdAt).toLocal();
                return now.difference(created).inHours >= 24;
              }).toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 10),

                    if (today.isNotEmpty) ...[
                      const Text(
                        "Today",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...today.map(buildCard),
                    ],

                    const SizedBox(height: 10),

                    if (older.isNotEmpty) ...[
                      const Text(
                        "Older",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...older.map(buildCard),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
