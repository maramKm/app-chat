import 'package:flutter/material.dart';
import 'package:app_chat/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_chat/models/chat_model.dart';
import 'package:app_chat/models/message_model.dart';
import 'package:app_chat/services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;
  final String currentUserId;

  const ChatScreen({
    super.key, 
    required this.chat, 
    required this.currentUserId
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late ChatService _chatService;
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(chatId: widget.chat.id);
    _loadMessages();
  }

  void _loadMessages() {
    _chatService.getMessagesStream().listen((messages) {
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });
      
      // Scroll vers le bas quand de nouveaux messages arrivent
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty 
                ? _buildEmptyChatWidget()
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            child: Center(
              child: Text(
                _getInitials(widget.chat.name),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.chat.name,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                widget.chat.isOnline ? 'En ligne' : 'Hors ligne',
                style: GoogleFonts.inter(
                  color: widget.chat.isOnline ? Colors.green : AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam, color: AppTheme.textPrimary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.call, color: AppTheme.textPrimary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
          onPressed: () => _showMoreOptions(),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isCurrentUser = message.senderId == widget.currentUserId;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.secondaryGradient,
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isCurrentUser
                    ? AppTheme.primaryGradient
                    : LinearGradient(
                      colors: [
                        AppTheme.cardDark,
                        AppTheme.cardDark.withOpacity(0.8),
                      ],
                    ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (isCurrentUser)
                    BoxShadow(
                      color: AppTheme.primaryCyan.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Afficher le nom de L'ENVOYEUR pour les messages REÇUS
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    message.text,
                    style: GoogleFonts.inter(
                      color: isCurrentUser ? Colors.white : AppTheme.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(message.timestamp),
                    style: GoogleFonts.inter(
                      color: isCurrentUser
                          ? Colors.white70
                          : AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser)
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyChatWidget() {
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
            'Commencez la conversation',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Envoyez votre premier message à ${widget.chat.name}',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.secondaryGradient,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.attach_file, size: 20),
              color: Colors.white,
              onPressed: () => _showAttachmentOptions(),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tapez un message...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: Icon(Icons.emoji_emotions,
                        color: AppTheme.textSecondary),
                    onPressed: () {},
                  ),
                ),
                maxLines: null,
                onSubmitted: (text) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryCyan.withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send, size: 20),
              color: Colors.white,
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: 200,
        child: Column(
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
              'Partager un média',
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo,
                  label: 'Galerie',
                  onTap: () {
                    Navigator.pop(context);
                    // Implémenter la galerie
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Caméra',
                  onTap: () {
                    Navigator.pop(context);
                    // Implémenter la caméra
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Fichier',
                  onTap: () {
                    Navigator.pop(context);
                    // Implémenter les fichiers
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.location_on,
                  label: 'Localisation',
                  onTap: () {
                    Navigator.pop(context);
                    // Implémenter la localisation
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
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
            ListTile(
              leading: Icon(Icons.person, color: AppTheme.primaryCyan),
              title: Text('Voir le profil', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Naviguer vers le profil
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: Colors.red),
              title: Text('Bloquer', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation();
              },
            ),
            ListTile(
              leading: Icon(Icons.report, color: Colors.orange),
              title: Text('Signaler', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text('Bloquer ${widget.chat.name}?', style: GoogleFonts.inter(color: Colors.white)),
        content: Text('Vous ne recevrez plus de messages de cette personne.', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implémenter le blocage
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.chat.name} a été bloqué'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text('Bloquer', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text('Signaler ${widget.chat.name}', style: GoogleFonts.inter(color: Colors.white)),
        content: Text('Pourquoi signalez-vous cette personne?', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Signalement envoyé')),
              );
            },
            child: Text('Signaler', style: GoogleFonts.inter(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      // Récupérer le nom de l'utilisateur depuis Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userName = userData?['name'] ?? 'Utilisateur';

      final newMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        senderId: widget.currentUserId,
        senderName: userName,
        timestamp: DateTime.now(),
        type: MessageType.text,
      );

      await _chatService.sendMessage(newMessage);
      await _chatService.updateLastMessage(text, widget.currentUserId, userName);
      _messageController.clear();
      
      print('✅ Message envoyé avec succès');
    } catch (error) {
      print('❌ Erreur: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Maintenant';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}min';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}