// lib/screens/chat_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_chat/theme/app_theme.dart';
import 'package:app_chat/models/chat_model.dart';
import 'package:app_chat/models/message_model.dart';
import 'package:app_chat/services/chat_service.dart';
import 'dart:io' show File, Directory; // NOTE: dart:io is NOT available on web — if you compile for web, remove usage or use conditional imports.

class ChatScreen extends StatefulWidget {
  final Chat chat;
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.chat,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late ChatService _chatService;
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();

  // emoji picker control
  bool _showEmoji = false;

  // audio recorder / player
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isRecording = false;
  bool _isPlayerInited = false;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(chatId: widget.chat.id);
    _loadMessages();
    _initAudio();
  }

  Future<void> _initAudio() async {
    if (!kIsWeb) {
      // 1 → permission micro
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        return;
      }

      // 2 → open recorder + player
      await _recorder.openRecorder();


      await _player.openPlayer();
      _isPlayerInited = true;

      // 3 → set codec AAC (important)
      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 200));
    }
  }

  Future<void> _playAudioFromMessage(Message message) async {
    try {
      if (!_isPlayerInited) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Player non prêt')));
        return;
      }

      final base64Audio = message.mediaUrl;
      if (base64Audio == null || base64Audio.isEmpty) return;

      final bytes = base64Decode(base64Audio);

      await _player.stopPlayer();

      await _player.startPlayer(
        fromDataBuffer: bytes,
        codec: Codec.aacADTS,
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur lecture audio: $e')));
    }
  }



  void _loadMessages() {
    _chatService.getMessagesStream().listen((messages) {
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });

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
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (!kIsWeb) {
      _recorder.closeRecorder();
      _player.closePlayer();
    }
    super.dispose();
  }

  // ---------- UI ----------

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
          if (_showEmoji) _buildEmojiPicker(),
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
          onPressed: _showMoreOptions,
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isCurrentUser = message.senderId == widget.currentUserId;

    Widget content;
    if (message.type == MessageType.image && (message.mediaUrl?.isNotEmpty ?? false)) {
      // image from base64
      final bytes = base64Decode(message.mediaUrl!);
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, height: 200, width: 200, fit: BoxFit.cover),
      );
    } else if (message.type == MessageType.file && (message.mediaUrl?.isNotEmpty ?? false)) {
      // show file tile with filename in text
      content = GestureDetector(
        onTap: () => _saveAndOpenFile(message),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardDark.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.text,
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (message.type == MessageType.audio && (message.mediaUrl?.isNotEmpty ?? false)) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            onPressed: () => _playAudioFromMessage(message),
          ),
          Text('Message vocal', style: GoogleFonts.inter(color: Colors.white)),
        ],
      );
    } else {
      content = Text(
        message.text,
        style: GoogleFonts.inter(
          color: isCurrentUser ? Colors.white : AppTheme.textPrimary,
          fontSize: 16,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.secondaryGradient),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isCurrentUser ? AppTheme.primaryGradient : LinearGradient(colors: [AppTheme.cardDark, AppTheme.cardDark.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isCurrentUser ? [BoxShadow(color: AppTheme.primaryCyan.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(message.senderName, style: GoogleFonts.inter(color: AppTheme.primaryCyan, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  content,
                  const SizedBox(height: 6),
                  Text(_formatMessageTime(message.timestamp), style: GoogleFonts.inter(color: isCurrentUser ? Colors.white70 : AppTheme.textSecondary, fontSize: 10)),
                ],
              ),
            ),
          ),
          if (isCurrentUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyChatWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: AppTheme.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('Commencez la conversation', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Envoyez votre premier message à ${widget.chat.name}', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Row(
        children: [
          // attachment / mic / emoji
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(gradient: AppTheme.secondaryGradient, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.attach_file, size: 20),
              color: Colors.white,
              onPressed: _showAttachmentOptions,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppTheme.darkBackground, borderRadius: BorderRadius.circular(25)),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          hintText: 'Tapez un message...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                          border: InputBorder.none),
                      maxLines: null,
                      onSubmitted: (t) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.emoji_emotions, color: AppTheme.textSecondary),
                    onPressed: () {
                      setState(() {
                        _showEmoji = !_showEmoji;
                        if (_showEmoji) FocusScope.of(context).unfocus();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // send / record
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
            child: IconButton(icon: const Icon(Icons.send, size: 20), color: Colors.white, onPressed: _sendMessage),
          ),
          const SizedBox(width: 8),
          // mic button (record)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: _isRecording ? Colors.redAccent : AppTheme.cardDark, shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(_isRecording ? Icons.mic_off : Icons.mic, color: Colors.white, size: 20),
              onPressed: kIsWeb ? null /* disabled on web for now */ : _toggleRecording,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmojiPicker() {
    return SizedBox(
      height: 260,
      child: ep.EmojiPicker(
        textEditingController: _messageController,
        config: ep.Config(
          height: 256,
          checkPlatformCompatibility: true,
          emojiViewConfig: ep.EmojiViewConfig(
            emojiSizeMax: 28,
            columns: 7,
            backgroundColor: AppTheme.cardDark,
            recentsLimit: 30,
          ),
          categoryViewConfig: ep.CategoryViewConfig(
            iconColorSelected: AppTheme.primaryCyan,
            iconColor: Colors.white70,
          ),
          bottomActionBarConfig: ep.BottomActionBarConfig(
            backgroundColor: AppTheme.cardDark,
          ),
          searchViewConfig: ep.SearchViewConfig(
            buttonIconColor: AppTheme.primaryCyan,
            backgroundColor: AppTheme.cardDark,
            hintText: "Search Emoji",
          ),
        ),
      ),
    );
  }


  // ---------- Attachments & sending ----------

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 75);
      if (picked == null) return;

      // On web & mobile: use readAsBytes (no File on web)
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).get();
      final userName = userDoc.data()?['name'] ?? 'Utilisateur';

      final newMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '',
        senderId: widget.currentUserId,
        senderName: userName,
        timestamp: DateTime.now(),
        type: MessageType.image,
        mediaUrl: base64Image,
      );

      await _chatService.sendMessage(newMessage);
      await _chatService.updateLastMessage('📷 Image', widget.currentUserId, userName);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image envoyée')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur image: $e')));
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'txt']);
      if (result == null) return;

      // On web: result.files.single.bytes is present; on native too sometimes
      final platformFile = result.files.single;
      Uint8List? bytes = platformFile.bytes;
      if (bytes == null && platformFile.path != null) {
        // mobile: read from path
        final f = File(platformFile.path!);
        bytes = await f.readAsBytes();
      }
      if (bytes == null) throw Exception('Impossible de lire le fichier');

      final base64File = base64Encode(bytes);
      final fileName = platformFile.name;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).get();
      final userName = userDoc.data()?['name'] ?? 'Utilisateur';

      final newMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: fileName,
        senderId: widget.currentUserId,
        senderName: userName,
        timestamp: DateTime.now(),
        type: MessageType.file,
        mediaUrl: base64File,
      );

      await _chatService.sendMessage(newMessage);
      await _chatService.updateLastMessage('📎 Fichier: $fileName', widget.currentUserId, userName);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📎 Fichier envoyé: $fileName')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur envoi fichier: $e')));
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        // STOP
        final data = await _recorder.stopRecorder();
        setState(() => _isRecording = false);

        if (data == null) return;

        // data contains raw audio bytes
        final base64Audio = base64Encode(data as List<int>);

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUserId)
            .get();
        final userName = userDoc.data()?['name'] ?? 'Utilisateur';

        final newMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: '',
          senderId: widget.currentUserId,
          senderName: userName,
          timestamp: DateTime.now(),
          type: MessageType.audio,
          mediaUrl: base64Audio,
        );

        await _chatService.sendMessage(newMessage);
        await _chatService.updateLastMessage(
            '🎙️ Message vocal', widget.currentUserId, userName);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message vocal envoyé')),
        );
      } else {
        // START
        final mic = await Permission.microphone.request();
        if (!mic.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone refusé')),
          );
          return;
        }

        await _recorder.startRecorder(
          toFile: 'audio_message.aac',
          codec: Codec.aacADTS,
        );


        setState(() => _isRecording = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }


  Future<void> _saveAndOpenFile(Message message) async {
    try {
      final base64 = message.mediaUrl ?? '';
      if (base64.isEmpty) return;
      final bytes = base64Decode(base64);
      final fileName = message.text.isNotEmpty ? message.text : 'file_${DateTime.now().millisecondsSinceEpoch}';

      // Write to temporary folder (native only)
      if (kIsWeb) {
        // on web: we can't write to disk here — suggest downloading or open in new tab (need web-specific code)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Téléchargement sur Web non implémenté dans ce snippet')));
        return;
      } else {
        final tmpPath = Directory.systemTemp.path;
        final filePath = p.join(tmpPath, fileName);
        final f = File(filePath);
        await f.writeAsBytes(bytes);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fichier sauvegardé: $filePath')));
        // optionally, open the file using external apps (requires package open_file)
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur ouverture fichier: $e')));
    }
  }

  // ---------- UI Helpers ----------

  Widget _buildAttachmentOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(width: 60, height: 60, decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: Colors.white, size: 30)),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: 220,
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Partager un média', style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _buildAttachmentOption(icon: Icons.photo, label: 'Galerie', onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              }),
              _buildAttachmentOption(icon: Icons.camera_alt, label: 'Caméra', onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              }),
              _buildAttachmentOption(icon: Icons.insert_drive_file, label: 'Fichier', onTap: () {
                Navigator.pop(context);
                _pickAndSendFile();
              }),
            ]),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          ListTile(leading: Icon(Icons.person, color: AppTheme.primaryCyan), title: Text('Voir le profil', style: GoogleFonts.inter(color: Colors.white)), onTap: () => Navigator.pop(context)),
          ListTile(leading: Icon(Icons.block, color: Colors.red), title: Text('Bloquer', style: GoogleFonts.inter(color: Colors.white)), onTap: () => Navigator.pop(context)),
          ListTile(leading: Icon(Icons.report, color: Colors.orange), title: Text('Signaler', style: GoogleFonts.inter(color: Colors.white)), onTap: () => Navigator.pop(context)),
        ]),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).get();
      final userName = userDoc.data()?['name'] ?? 'Utilisateur';

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
      if (_showEmoji) setState(() => _showEmoji = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) return 'Maintenant';
    if (difference.inHours < 1) return '${difference.inMinutes}min';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
