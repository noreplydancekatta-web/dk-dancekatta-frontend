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
  Timer? _pollTimer;

  Set<String> _knownIds = {};
  bool _firstPoll = true;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _buildTabs();

    _poll();

    // 🔥 Only change: faster polling (10 sec)
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _buildTabs() {
    _tabs = [
      HomeTab(user: _currentUser),
      ExploreScreen(user: _currentUser),
      MyBatchesScreen(
        user: _currentUser,
        goToHomeTab: () => setState(() => _currentIndex = 0),
      ),
      MessagesScreen(user: _currentUser),
    ];
  }

  Future<void> _poll() async {
    try {
      final announcements = await AnnouncementService.fetchAnnouncements(
        _currentUser.id!,
      );

      final seenIds = await InboxService.fetchSeenAnnouncementIds(
        _currentUser.id!,
      );

      // 🔴 red dot logic (same UI, just better working)
      hasNewMessages.value = announcements.any((a) => !seenIds.contains(a.id));

      final currentIds = announcements.map((a) => a.id).toSet();

      if (_firstPoll) {
        _knownIds = currentIds;
        _firstPoll = false;
        return;
      }

      final hasNew = currentIds.any((id) => !_knownIds.contains(id));
      _knownIds = currentIds;

      if (hasNew && mounted) {
        setState(() => _buildTabs());
      }
    } catch (e) {
      debugPrint('Poll error: $e');
    }
  }

  Widget _buildProfileAvatar() {
    final photo = _currentUser.profilePhoto;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final url = hasPhoto
        ? (photo.startsWith('http') ? photo : 'http://147.93.19.17:5002$photo')
        : null;

    return GestureDetector(
      onTap: () async {
        if (_currentUser.id == null || _currentUser.id!.isEmpty) return;

        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(user: _currentUser)),
        );

        if (result is UserModel) {
          setState(() {
            _currentUser = result;
            _buildTabs();
          });
        }
      },
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey[200],
        child: ClipOval(
          child: hasPhoto
              ? Image.network(
                  url!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person, color: Colors.grey),
                )
              : const Icon(Icons.person, color: Colors.grey),
        ),
      ),
    );
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
              title: const Text(
                'Dance Katta',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildProfileAvatar(),
                ),
              ],
            )
          : null,
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
            label: 'Messages',
            icon: ValueListenableBuilder<bool>(
              valueListenable: hasNewMessages,
              builder: (_, hasNew, __) => Stack(
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
