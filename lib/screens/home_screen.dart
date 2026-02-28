import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/user_model.dart';
import 'profile_screen.dart';
import 'home_tab.dart';
import 'explore_tab.dart';
import 'messages_screen.dart';
import '../constants.dart'; // ✅ import for getFullImageUrl
import 'my_batches_screen.dart';

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

  /// Returns an ImageProvider for the profile image
  ImageProvider? _getProfileImage(UserModel user) {
    final url = getFullImageUrl(user.profilePhoto); // ✅ use shared helper

    if (url.isNotEmpty) {
      return NetworkImage(url);
    }

    // Fallback → no image
    return null;
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
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    icon: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _getProfileImage(_currentUser),
                      child: _getProfileImage(_currentUser) == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    onPressed: _navigateToProfile,
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
