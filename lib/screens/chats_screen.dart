import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_chat/theme/app_theme.dart';
import 'package:app_chat/models/chat_model.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final List<Chat> chats = [
    Chat(
      id: '1',
      name: 'Alex Johnson',
      lastMessage: 'Hey, how are you doing?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      unreadCount: 2,
      isOnline: true,
      profileImage: '',
    ),
    Chat(
      id: '2',
      name: 'Sarah Miller',
      lastMessage: 'Meeting at 3 PM tomorrow',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: 0,
      isOnline: false,
      profileImage: '',
    ),
    Chat(
      id: '3',
      name: 'Mike Chen',
      lastMessage: 'Sent you a photo',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      unreadCount: 1,
      isOnline: true,
      profileImage: '',
    ),
    Chat(
      id: '4',
      name: 'Design Team',
      lastMessage: 'Emily: Updated the mockups',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      isOnline: false,
      isGroup: true,
      profileImage: '',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.darkBackground,
      child: Column(
        children: [
          _buildStoriesSection(),

          Expanded(
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) => _buildChatItem(chats[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesSection() {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildAddStoryButton(),
          const SizedBox(width: 16),
          ...List.generate(5, (index) => _buildStoryItem(index)),
        ],
      ),
    );
  }

  Widget _buildAddStoryButton() {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryCyan,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.add,
            color: AppTheme.primaryCyan,
            size: 30,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your Story',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStoryItem(int index) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              shape: BoxShape.circle,
              image: DecorationImage(
                image: NetworkImage(
                    'https://i.pravatar.cc/150?img=${index + 10}'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'User ${index + 1}',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildChatItem(Chat chat) {
    return ListTile(
      leading: Stack(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: chat.profileImage.isEmpty
                  ? DecorationImage(
                image: NetworkImage(
                    'https://i.pravatar.cc/150?img=${chat.id}'),
                fit: BoxFit.cover,
              )
                  : null,
              gradient: chat.profileImage.isEmpty
                  ? null
                  : AppTheme.primaryGradient,
            ),
            child: chat.profileImage.isEmpty
                ? null
                : Icon(
              chat.isGroup ? Icons.group : Icons.person,
              color: Colors.white,
            ),
          ),
          if (chat.isOnline && !chat.isGroup)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.darkBackground,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        chat.name,
        style: GoogleFonts.inter(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        chat.lastMessage,
        style: GoogleFonts.inter(
          color: AppTheme.textSecondary,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(chat.timestamp),
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                chat.unreadCount.toString(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(chat: chat),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}