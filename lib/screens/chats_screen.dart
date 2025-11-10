import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_chat/theme/app_theme.dart';
import 'package:app_chat/models/chat_model.dart';
import 'package:app_chat/services/chat_service.dart';
import 'chat_screen.dart';

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
    _initializeChatsStream();
  }

  void _initializeChatsStream() {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _chatsStream = ChatService.getUserChatsStream(currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.darkBackground,
      child: Column(
        children: [
          _buildStoriesSection(),
          Expanded(
            child: _buildChatsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsList() {
    return StreamBuilder<List<Chat>>(
      stream: _chatsStream,
      builder: (context, snapshot) {
        // État de chargement
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }

        // Gestion des erreurs
        if (snapshot.hasError) {
          return _buildErrorWidget('Erreur de chargement des conversations');
        }

        // Données reçues
        final chats = snapshot.data ?? [];

        if (chats.isEmpty) {
          return _buildEmptyChatsWidget();
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          backgroundColor: AppTheme.darkBackground,
          color: AppTheme.primaryCyan,
          child: ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: AppTheme.textSecondary.withOpacity(0.1),
            ),
            itemBuilder: (context, index) => _buildChatItem(chats[index]),
          ),
        );
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryCyan),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement des conversations...',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
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
            'Commencez une nouvelle conversation',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              color: Colors.red,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _initializeChatsStream();
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Réessayer',
              style: GoogleFonts.inter(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesSection() {
    return Container(
      height: 120,
      padding: const EdgeInsets.only(bottom: 16),
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
    final profileImage = chat.profileImage.isNotEmpty 
        ? NetworkImage(chat.profileImage)
        : NetworkImage('https://i.pravatar.cc/150?img=${chat.id.hashCode % 70}');

    return Dismissible(
      key: Key(chat.id),
      direction: DismissDirection.endToStart,
      background: _buildDeleteBackground(),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(chat);
      },
      onDismissed: (direction) {
        _deleteChat(chat);
      },
      child: ListTile(
        leading: Stack(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: profileImage,
                  fit: BoxFit.cover,
                ),
              ),
              child: chat.profileImage.isEmpty && !chat.isGroup
                  ? Icon(
                      Icons.person,
                      color: Colors.white,
                    )
                  : null,
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
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
                const SizedBox(height: 8),
                // BOUTON SUPPRESSION AVEC CERCLE ROUGE
                GestureDetector(
                  onTap: () {
                    _showDeleteConfirmationDirect(chat);
                  },
                  child: Container(
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Badge messages non lus
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
          _navigateToChat(chat);
        },
        onLongPress: () {
          _showChatOptions(chat);
        },
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade900],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(
            Icons.delete,
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 20),
          Text(
            'Supprimer',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(Chat chat) async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardDark,
          title: Text(
            'Supprimer la conversation',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Voulez-vous vraiment supprimer la conversation avec ${chat.name} ? Cette action est irréversible.',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Supprimer',
                style: GoogleFonts.inter(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showDeleteConfirmationDirect(Chat chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Text(
              'Supprimer',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Supprimer la conversation avec ${chat.name} ?',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chat);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _deleteChat(Chat chat) async {
    try {
      await ChatService.deleteChat(chat.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conversation avec ${chat.name} supprimée'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Erreur suppression: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showChatOptions(Chat chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicateur de glissement
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Options
              ListTile(
                leading: Icon(Icons.archive, color: AppTheme.primaryCyan),
                title: Text(
                  'Archiver',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _archiveChat(chat);
                },
              ),
              
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text(
                  'Supprimer',
                  style: GoogleFonts.inter(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(chat);
                },
              ),
              
              ListTile(
                leading: Icon(Icons.block, color: Colors.orange),
                title: Text(
                  'Bloquer',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockDialog(chat);
                },
              ),
              
              const SizedBox(height: 10),
              Divider(color: AppTheme.textSecondary.withOpacity(0.3)),
              
              ListTile(
                leading: Icon(Icons.cancel, color: AppTheme.textSecondary),
                title: Text(
                  'Annuler',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteDialog(Chat chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(
          'Supprimer définitivement',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'La conversation avec ${chat.name} sera supprimée définitivement. Cette action ne peut pas être annulée.',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chat);
            },
            child: Text(
              'Supprimer',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _archiveChat(Chat chat) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      await ChatService.archiveChat(chat.id, currentUserId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conversation avec ${chat.name} archivée'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'archivage: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBlockDialog(Chat chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(
          'Bloquer ${chat.name}',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Vous ne recevrez plus de messages de cette personne. Ils ne pourront pas non plus voir votre statut en ligne.',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implémentez la logique de blocage ici
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${chat.name} a été bloqué'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: Text(
              'Bloquer',
              style: GoogleFonts.inter(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToChat(Chat chat) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chat: chat,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (difference.inMinutes < 1) {
      return 'Maintenant';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (timestamp.isAfter(yesterday)) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}