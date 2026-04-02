import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_model.dart';
import 'profile_screen.dart';
import 'home_tab.dart';
import 'explore_tab.dart';
import 'messages_screen.dart';
import 'my_batches_screen.dart';
import '../services/announcement_service.dart';
import '../services/inbox_service.dart';

/// Global notifier for red dot on messages
final ValueNotifier<bool> hasNewMessages = ValueNotifier(false);

class HomeScreen extends StatefulWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late UserModel _currentUser;
  late List<Widget> _tabs;

  Timer? _messageTimer;

  /// Profile image helper
  ImageProvider? _getProfileImage(UserModel user) {
    final photo = user.profilePhoto;

    if (photo == null || photo.isEmpty) {
      return null;
    }

    // Add cache-busting so updated photos load immediately after profile edit
    final cacheBuster = '?t=${photo.hashCode}';

    if (photo.startsWith('http')) {
      return NetworkImage('$photo$cacheBuster');
    }

    return NetworkImage('http://147.93.19.17:5002$photo$cacheBuster');
  }

  /// Navigate to profile
  Future<void> _navigateToProfile() async {
    if (_currentUser.id == null || _currentUser.id!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User ID missing")));
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(user: _currentUser),
      ),
    );

    /// Refresh UI if profile updated
    if (result != null && result is UserModel) {
      // Clear image cache so the new profile photo loads immediately
      imageCache.clear();
      imageCache.clearLiveImages();
      setState(() {
        _currentUser = result;
        _buildTabs();
      });
    }
  }

  /// Create tabs
  void _buildTabs() {
    _tabs = [
      HomeTab(user: _currentUser),

      ExploreScreen(user: _currentUser),

      MyBatchesScreen(
        user: _currentUser,
        goToHomeTab: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),

      MessagesScreen(user: _currentUser),
    ];
  }

  @override
  void initState() {
    super.initState();

    _currentUser = widget.user;

    _buildTabs();

    /// Start message polling
    _startMessagePolling();
  }

  /// Poll messages every 30 seconds
  void _startMessagePolling() {
    _checkUnseenMessages();

    _messageTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkUnseenMessages(),
    );
  }

  /// Check unseen announcements
  Future<void> _checkUnseenMessages() async {
    try {
      final announcements = await AnnouncementService.fetchAnnouncements(
        _currentUser.id!,
      );

      final seenIds = await InboxService.fetchSeenAnnouncementIds(
        _currentUser.id!,
      );

      final hasUnseen = announcements.any((a) => !seenIds.contains(a.id));

      hasNewMessages.value = hasUnseen;
    } catch (e) {
      debugPrint("Notification error: $e");
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// AppBar only on HomeTab
      appBar: _currentIndex == 0
          ? AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.white,
              elevation: 0,

              title: const Text(
                "Dance Katta",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),

              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: _navigateToProfile,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _getProfileImage(_currentUser),
                      child: _getProfileImage(_currentUser) == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                  ),
                ),
              ],
            )
          : null,

      /// Keep tab states alive
      body: IndexedStack(index: _currentIndex, children: _tabs),

      /// Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,

        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // Rebuild MyBatches and Messages tabs each time selected
            // so new enrollments and announcements show immediately
            if (index == 2 || index == 3) {
              _buildTabs();
            }
          });
        },

        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,

        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Studios",
          ),

          const BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: "Batches",
          ),

          const BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: "My Batches",
          ),

          BottomNavigationBarItem(
            icon: ValueListenableBuilder<bool>(
              valueListenable: hasNewMessages,
              builder: (context, hasNew, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.message),

                    if (hasNew)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            label: "Messages",
          ),
        ],
      ),
    );
  }
}
