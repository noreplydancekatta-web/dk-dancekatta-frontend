import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/user_model.dart';
import 'profile_screen.dart';
import 'home_tab.dart';
import 'explore_tab.dart';
import 'messages_screen.dart';
import '../constants.dart'; // ✅ import for getFullImageUrl
import 'my_batches_screen.dart';
import 'dart:async';
import '../services/announcement_service.dart';
import '../services/inbox_service.dart';

// Global ValueNotifier to manage the state of new messages
final ValueNotifier<bool> hasNewMessages = ValueNotifier<bool>(false);

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

  ImageProvider? _getProfileImage(UserModel user) {
    final photoUrl = user.profilePhoto;

    // If photo URL is null or empty, return null
    if (photoUrl == null || photoUrl.isEmpty) {
      return null;
    }

    // If already a full URL (from Google Sign-In)
    if (photoUrl.startsWith('http')) {
      return NetworkImage(photoUrl);
    }

    // Otherwise, treat as relative path from backend
    return NetworkImage('http://147.93.19.17:5002$photoUrl');
  }

  void _navigateToProfile() async {
    if (_currentUser.id == null || _currentUser.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User ID missing. Please try again.")),
      );
      return;
    }
    // Await result from ProfileScreen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(user: _currentUser),
      ),
    );
    // If result is a UserModel, update the user and rebuild tabs
    if (result is UserModel) {
      setState(() {
        _currentUser = result;
        _tabs = [
          HomeTab(user: _currentUser),
          ExploreScreen(user: _currentUser),
          MyBatchesScreen(user: _currentUser),
          MessagesScreen(user: _currentUser),
        ];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _tabs = [
      HomeTab(user: _currentUser),
      ExploreScreen(user: _currentUser),
      MyBatchesScreen(user: _currentUser),
      MessagesScreen(user: _currentUser),
    ];

    // ← ADD THIS
    _startMessagePolling();
  }

  Timer? _messageCheckTimer;

  void _startMessagePolling() async {
    // Check immediately on startup
    await _checkUnseenMessages();

    // Then check every 30 seconds
    _messageCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkUnseenMessages(),
    );
  }

  Future<void> _checkUnseenMessages() async {
    try {
      final announcements = await AnnouncementService.fetchAnnouncements(
        _currentUser.id!,
      );
      final seenIds = await InboxService.fetchSeenAnnouncementIds(
        _currentUser.id!,
      );
      final hasUnseen = announcements.any((a) => !seenIds.contains(a.id));
      hasNewMessages.value = hasUnseen; // ← this triggers the red dot
    } catch (e) {
      debugPrint('❌ Error checking messages: $e');
    }
  }

  @override
  void dispose() {
    _messageCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _currentIndex == 0
          ? AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.white,
              elevation: 0,
              title: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Dance ',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: 'Katta',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 👇 ADD THIS PART
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
                          ? const Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Studios',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Batches',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'My Batches',
          ),

          BottomNavigationBarItem(
            icon: ValueListenableBuilder<bool>(
              valueListenable: hasNewMessages,
              builder: (context, value, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.message),
                    if (value)
                      Positioned(
                        top: -2,
                        right: -2,
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
            label: 'Messages',
          ),
        ],
      ),
    );
  }
}
