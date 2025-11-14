import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_chat/theme/app_theme.dart';
import 'package:app_chat/models/chat_model.dart';
import 'package:app_chat/services/chat_service.dart';
import 'package:app_chat/screens/chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late Stream<List<Chat>> _chatsStream;

  @override
  void initState() {
    super.initState();
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _chatsStream = ChatService.getUserChatsStream(currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.darkBackground,
      child: StreamBuilder<List<Chat>>(
        stream: _chatsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoading();
          }
          if (snapshot.hasError) {
            return _buildError("Erreur de chargement");
          }

          final chats = snapshot.data ?? [];
          if (chats.isEmpty) return _buildEmpty();

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            color: AppTheme.primaryCyan,
            backgroundColor: AppTheme.darkBackground,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: chats.length,
              itemBuilder: (context, i) => _buildChatTile(chats[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading() => Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation(AppTheme.primaryCyan),
    ),
  );

  Widget _buildError(String msg) => Center(
    child: Text(msg, style: const TextStyle(color: Colors.red)),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chat_bubble_outline,
            size: 80, color: AppTheme.textSecondary.withOpacity(0.5)),
        const SizedBox(height: 16),
        Text(
          'Aucune conversation',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Commencez une nouvelle discussion',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    ),
  );

  Widget _buildChatTile(Chat chat) {
    final hasPhoto = chat.profileImage.isNotEmpty;
    final imageProvider = hasPhoto ? NetworkImage(chat.profileImage) : null;
    final firstLetter = chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?';

    return GestureDetector(
      onLongPress: () => _showChatOptions(chat),
      onTap: () => _navigateToChat(chat),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                  hasPhoto ? Colors.transparent : AppTheme.primaryCyan,
                  backgroundImage: imageProvider,
                  child: !hasPhoto
                      ? Text(
                    firstLetter,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),
                if (chat.isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.cardDark,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.name,
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chat.lastMessage.isNotEmpty
                        ? chat.lastMessage
                        : "Démarrer une conversation",
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(chat.timestamp),
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                if (chat.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      chat.unreadCount.toString(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showChatOptions(Chat chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(
                "Supprimer la discussion",
                style: GoogleFonts.inter(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                await ChatService.deleteChat(chat.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                    Text("Discussion avec ${chat.name} supprimée ✅"),
                    backgroundColor: Colors.redAccent,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: AppTheme.textSecondary),
              title: Text(
                "Annuler",
                style: GoogleFonts.inter(color: AppTheme.textSecondary),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToChat(Chat chat) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chat: chat,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return "Maintenant";
    if (diff.inHours < 1) return "${diff.inMinutes}m";
    if (diff.inDays < 1) return "${diff.inHours}h";
    if (diff.inDays == 1) return "Hier";
    return "${timestamp.day}/${timestamp.month}";
  }
}
