import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_chat/theme/app_theme.dart';
import 'chats_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_chat/services/friend_service.dart';
import 'package:app_chat/services/nfc_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile_screen.dart'; 
import 'package:app_chat/services/nfc_write_service.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

@override
void initState() {
  super.initState();

  // Lire automatiquement NFC (déjà intégré)
  NFCService.startNFC((userIdScanned) async {
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userIdScanned)
        .get();

    if (!mounted || !userSnap.exists) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: userIdScanned,
          userData: userSnap.data()!,
        ),
      ),
    );
  });

  // Écrit ton UID dans le tag (si user connecté)
  Future.delayed(const Duration(seconds: 2), () {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      NFCWriteService.writeUserId(uid);
    }
  });
}



  final List<Widget> _screens = [
    const ChatsScreen(),
    const ContactsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: Text(
            'KONVO',
            style: GoogleFonts.orbitron(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AppTheme.textPrimary),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ChatSearchDelegate(),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: AppTheme.textPrimary),
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildFloatingActionButton() {
    if (_currentIndex == 1) {
      return FloatingActionButton(
        onPressed: () => _showAddContactModal(context),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: AppTheme.secondaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.person_add, color: Colors.white),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Options',
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _buildModalOption(
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'App preferences and configuration',
              onTap: () {
                Navigator.pop(context);
                // Naviguer vers les paramètres
              },
            ),
            const SizedBox(height: 15),
            _buildModalOption(
              icon: Icons.help,
              title: 'Help & Support',
              subtitle: 'Get help and contact support',
              onTap: () {
                Navigator.pop(context);
                // Naviguer vers l'aide
              },
            ),
            const SizedBox(height: 15),
            _buildModalOption(
              icon: Icons.info,
              title: 'About',
              subtitle: 'Learn about KONVO app',
              onTap: () {
                Navigator.pop(context);
                // Naviguer vers about
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


  void _showAddContactModal(BuildContext context) {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FriendService _friendService = FriendService();
    final currentUser = _auth.currentUser;

    if (currentUser == null) return;

    String searchQuery = "";

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Add Contact',
                    style: GoogleFonts.orbitron(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🔍 Search field
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by username or email...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: Icon(Icons.search, color: AppTheme.primaryCyan),
                      filled: true,
                      fillColor: AppTheme.darkBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: TextStyle(color: AppTheme.textPrimary),
                    onChanged: (val) => setModalState(() => searchQuery = val.trim()),
                  ),
                  const SizedBox(height: 20),

                  // 🧩 Real-time user list
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('users').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final allUsers = snapshot.data!.docs;
                        final filtered = allUsers.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name =
                          (data['name'] ?? '').toString().toLowerCase();
                          final email =
                          (data['email'] ?? '').toString().toLowerCase();
                          final match = searchQuery.isEmpty ||
                              name.contains(searchQuery.toLowerCase()) ||
                              email.contains(searchQuery.toLowerCase());
                          return match && doc.id != currentUser.uid;
                        }).toList();

                        return StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('friend_requests')
                              .snapshots(),
                          builder: (context, reqSnapshot) {
                            if (!reqSnapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final requests = reqSnapshot.data!.docs;

                            return ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final userDoc = filtered[index];
                                final userId = userDoc.id;
                                final data =
                                userDoc.data() as Map<String, dynamic>;
                                final name = data['name'] ?? 'Utilisateur';
                                final email = data['email'] ?? '';
                                final profileImage =
                                    data['profileImage'] ?? '';

                                // Vérifier les états
                                final outgoing = requests.where((r) =>
                                r['fromUserId'] == currentUser.uid &&
                                    r['toUserId'] == userId &&
                                    r['status'] == 'pending');

                                final incoming = requests.where((r) =>
                                r['fromUserId'] == userId &&
                                    r['toUserId'] == currentUser.uid &&
                                    r['status'] == 'pending');

                                final accepted = requests.where((r) =>
                                ((r['fromUserId'] == currentUser.uid &&
                                    r['toUserId'] == userId) ||
                                    (r['fromUserId'] == userId &&
                                        r['toUserId'] == currentUser.uid)) &&
                                    r['status'] == 'accepted');

                                // Déjà amis → cacher
                                if (accepted.isNotEmpty)
                                  return const SizedBox.shrink();

                                String label = "Add";
                                Color color = AppTheme.primaryCyan;
                                VoidCallback? onPressed;

                                if (outgoing.isNotEmpty) {
                                  label = "Invitation envoyée";
                                  color = Colors.grey;
                                  onPressed = null;
                                } else if (incoming.isNotEmpty) {
                                  label = "Accepter";
                                  color = Colors.green;
                                  final reqId = incoming.first.id;
                                  final reqData =
                                  incoming.first.data() as Map<String, dynamic>;
                                  onPressed = () async {
                                    await _friendService.acceptFriendRequest(
                                        reqId, reqData);
                                  };
                                } else {
                                  onPressed = () async {
                                    await _friendService.sendFriendRequest(
                                      fromUserId: currentUser.uid,
                                      toUserId: userId,
                                      fromUserInfo: {
                                        'name': currentUser.displayName ?? '',
                                        'email': currentUser.email ?? '',
                                        'profileImage': currentUser.photoURL ?? '',
                                      },
                                      toUserInfo: {
                                        'name': data['name'] ?? '',
                                        'email': data['email'] ?? '',
                                        'profileImage': data['profileImage'] ?? '',
                                      },
                                    );

                                  };
                                }

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryCyan,
                                    backgroundImage: profileImage.isNotEmpty
                                        ? NetworkImage(profileImage)
                                        : null,
                                    child: profileImage.isEmpty
                                        ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : "?",
                                      style:
                                      const TextStyle(color: Colors.white),
                                    )
                                        : null,
                                  ),
                                  title: Text(name,
                                      style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(email,
                                      style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13)),
                                  trailing: ElevatedButton(
                                    onPressed: onPressed,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: color,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildModalOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          color: AppTheme.textSecondary,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppTheme.cardDark,
          selectedItemColor: AppTheme.primaryCyan,
          unselectedItemColor: AppTheme.textSecondary,
          selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: _currentIndex == 0
                    ? BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                )
                    : null,
                child: Icon(
                  _currentIndex == 0 ? Icons.chat : Icons.chat_bubble_outline,
                  size: 24,
                  color: _currentIndex == 0 ? Colors.white : AppTheme.textSecondary,
                ),
              ),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: _currentIndex == 1
                    ? BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                )
                    : null,
                child: Icon(
                  _currentIndex == 1 ? Icons.people : Icons.people_outline,
                  size: 24,
                  color: _currentIndex == 1 ? Colors.white : AppTheme.textSecondary,
                ),
              ),
              label: 'Contacts',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: _currentIndex == 2
                    ? BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                )
                    : null,
                child: Icon(
                  _currentIndex == 2 ? Icons.person : Icons.person_outline,
                  size: 24,
                  color: _currentIndex == 2 ? Colors.white : AppTheme.textSecondary,
                ),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class ChatSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear, color: AppTheme.textPrimary),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return Container(
      color: AppTheme.darkBackground,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 0, // Remplacez par vos résultats de recherche
        itemBuilder: (context, index) => Card(
          color: AppTheme.cardDark,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryCyan,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=$index'),
            ),
            title: Text(
              'User $index',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              'Last message...',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            onTap: () {
              close(context, 'User $index');
            },
          ),
        ),
      ),
    );
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: AppTheme.darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: AppTheme.cardDark,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: AppTheme.textSecondary),
        border: InputBorder.none,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
        ),
      ),
    );
  }
}