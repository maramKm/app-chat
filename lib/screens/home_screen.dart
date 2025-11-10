import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_chat/theme/app_theme.dart';
import 'chats_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

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
    if (_currentIndex == 0) {
      return FloatingActionButton(
        onPressed: () => _showNewChatModal(context),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryCyan.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.chat, color: Colors.white),
        ),
      );
    } else if (_currentIndex == 1) {
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

  void _showNewChatModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      isScrollControlled: true,
      builder: (context) => Container(
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
              'New Conversation',
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _buildModalOption(
              icon: Icons.person_add,
              title: 'New Contact',
              subtitle: 'Start chat with new contact',
              onTap: () {
                Navigator.pop(context);
                // Implémenter la logique nouveau contact
              },
            ),
            const SizedBox(height: 15),
            _buildModalOption(
              icon: Icons.group,
              title: 'New Group',
              subtitle: 'Create group conversation',
              onTap: () {
                Navigator.pop(context);
                // Implémenter la logique nouveau groupe
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAddContactModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: 0, // Remplacez par vos contacts suggérés
                itemBuilder: (context, index) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryCyan,
                    child: Text(
                      'U',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    'Suggested User',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    'user@example.com',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryCyan,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'Add',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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