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
import 'package:konvo/theme/app_theme.dart';
import 'package:konvo/models/chat_model.dart';
import 'package:konvo/models/message_model.dart';
import 'package:konvo/models/call_model.dart';
import 'package:konvo/services/chat_service.dart';
import 'dart:io' show File, Directory;
import 'package:path_provider/path_provider.dart';
import 'package:konvo/services/call_manager.dart'; 
import 'call_screen.dart';
import 'incoming_call_screen.dart';

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
  final CallManager _callManager =
      CallManager(); // ← CHANGED: Use CallManager singleton
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
    _listenForIncomingCalls();
    _setupCallManagerCallbacks(); // ← ADDED: Setup callbacks for call manager
  }

  // ADDED: Setup call manager callbacks
  void _setupCallManagerCallbacks() {
    _callManager.setupCallbacks(
      onRemoteStream: (stream) {
        // This will be handled in CallScreen
      },
      onConnectionState: (state) {
        // This will be handled in CallScreen
      },
      onMuteState: (isMuted) {
        // This will be handled in CallScreen
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Call Error: $error')));
        }
      },
    );
  }

  Future<void> _initAudio() async {
    if (!kIsWeb) {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        return;
      }

      await _recorder.openRecorder();
      await _player.openPlayer();
      _isPlayerInited = true;

      await _recorder.setSubscriptionDuration(
        const Duration(milliseconds: 200),
      );
    }
  }

  Future<void> _playAudioFromMessage(Message message) async {
    try {
      if (!_isPlayerInited && !kIsWeb) {
        await _initAudio();
      }

      final bytes = base64Decode(message.mediaUrl!);

      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        final filePath =
            "${dir.path}/audio_temp_${DateTime.now().millisecondsSinceEpoch}.aac";
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        await _player.startPlayer(fromURI: filePath, codec: Codec.aacADTS);

        _player.onProgress?.listen((event) {}).onDone(() {
          file.delete();
        });
      } else {
        await _player.startPlayer(fromDataBuffer: bytes, codec: Codec.aacADTS);
      }
    } catch (e) {
      print("Audio play error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de lire le vocal")),
      );
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
    _callManager.dispose(); // ← CHANGED: Dispose call manager
    if (!kIsWeb) {
      _recorder.closeRecorder();
      _player.closePlayer();
      _cleanupTempFiles();
    }
    super.dispose();
  }

  Future<void> _cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      for (var file in files) {
        if (file.path.contains('audio_temp_') || file.path.contains('audio_')) {
          file.deleteSync();
        }
      }
    } catch (e) {
      print('Cleanup error: $e');
    }
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
                      return MessageBubble(
                        key: ValueKey(message.id),
                        message: message,
                        isCurrentUser: message.senderId == widget.currentUserId,
                        onPlayAudio: () => _playAudioFromMessage(message),
                        onOpenFile: () => _saveAndOpenFile(message),
                      );
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
    final String otherUserId = widget.chat.otherUserId;

    // Debug pour vérifier
    print('=== DEBUG Chat Information ===');
    print('Chat ID: ${widget.chat.id}');
    print('Chat Name: ${widget.chat.name}');
    print('Other User ID: $otherUserId');
    print('Current User ID: ${widget.currentUserId}');
    print('==============================');

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Avatar avec initiales
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
          // Informations utilisateur avec statut en temps réel
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(otherUserId)
                .snapshots(),
            builder: (context, snapshot) {
              // États de chargement
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildUserInfoLoading();
              }

              // États d'erreur ou document non trouvé
              if (snapshot.hasError) {
                print('Erreur StreamBuilder: ${snapshot.error}');
                return _buildUserInfoOffline();
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                print('Document utilisateur non trouvé pour ID: $otherUserId');
                return _buildUserInfoOffline();
              }

              // Données utilisateur récupérées avec succès
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final isOnline = _isUserReallyOnline(data);

              // Debug des données utilisateur
              print('=== Données utilisateur mises à jour ===');
              print('Nom: ${data['name']}');
              print('isOnline: ${data['isOnline']}');
              print('lastSeen: ${data['lastSeen']}');
              print('lastHeartbeat: ${data['lastHeartbeat']}');
              print('Statut calculé: $isOnline');
              print('Timestamp: ${DateTime.now()}');
              print('========================================');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom de l'utilisateur
                  Text(
                    data['name'] ?? widget.chat.name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  // Statut en ligne/hors ligne
                  Text(
                    isOnline ? 'En ligne' : _getLastSeenText(data['lastSeen']),
                    style: GoogleFonts.inter(
                      color: isOnline ? Colors.green : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      actions: [
        // Bouton d'appel vocal
        _buildCallButton(userId: otherUserId),
      ],
    );
  }

  bool _isUserReallyOnline(Map<String, dynamic> userData) {
    try {
      final isOnline = userData['isOnline'] ?? false;
      final lastHeartbeat = userData['lastHeartbeat'];
      final lastSeen = userData['lastSeen'];

      print('=== Vérification statut détaillée ===');
      print('isOnline: $isOnline');
      print('lastHeartbeat: $lastHeartbeat');
      print('lastSeen: $lastSeen');

      // Si l'utilisateur est explicitement marqué comme hors ligne
      if (!isOnline) {
        print('Utilisateur explicitement hors ligne (isOnline: false)');
        return false;
      }

      // Si pas de heartbeat, utiliser lastSeen avec une tolérance plus courte
      if (lastHeartbeat == null) {
        print(' Pas de heartbeat, utilisation de lastSeen');

        if (lastSeen == null) {
          print('Aucune donnée de présence trouvée');
          return false;
        }

        final lastSeenTime = lastSeen is Timestamp
            ? lastSeen.toDate()
            : DateTime.fromMillisecondsSinceEpoch(lastSeen);
        final now = DateTime.now();
        final difference = now.difference(lastSeenTime);

        // Réduire la tolérance à 2 minutes pour lastSeen
        final result = difference.inMinutes < 2;
        print(
          'Statut basé sur lastSeen: $result (différence: ${difference.inMinutes}min)',
        );
        return result;
      }

      // Convertir le timestamp heartbeat
      DateTime heartbeatTime;
      if (lastHeartbeat is Timestamp) {
        heartbeatTime = lastHeartbeat.toDate();
      } else if (lastHeartbeat is int) {
        heartbeatTime = DateTime.fromMillisecondsSinceEpoch(lastHeartbeat);
      } else {
        print('Format de heartbeat non reconnu');
        return false;
      }

      // Vérifier si le heartbeat est récent (moins de 60 secondes)
      final now = DateTime.now();
      final difference = now.difference(heartbeatTime);

      final bool isReallyOnline = difference.inSeconds < 60;
      print(
        '📊 Statut basé sur heartbeat: $isReallyOnline (différence: ${difference.inSeconds}s)',
      );
      print('=====================================');

      return isReallyOnline;
    } catch (e) {
      print('Erreur vérification présence: $e');
      return false;
    }
  }

  Widget _buildCallButton({required String userId}) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return IconButton(
            icon: Icon(Icons.call, color: Colors.grey),
            onPressed: null,
            tooltip: 'Chargement...',
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return IconButton(
            icon: Icon(Icons.call, color: Colors.grey),
            onPressed: null,
            tooltip: 'Utilisateur hors ligne',
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isOnline = _isUserReallyOnline(data);

        return IconButton(
          icon: Icon(
            Icons.call,
            color: isOnline ? AppTheme.textPrimary : Colors.grey,
          ),
          onPressed: isOnline ? () => _initiateCall(userId) : null,
          tooltip: isOnline ? 'Appel vocal' : 'Utilisateur hors ligne',
        );
      },
    );
  }

// CHANGED: Updated call initiation using CallManager
Future<void> _initiateCall(String receiverId) async {
  try {
    print('🔍 DEBUG: _initiateCall started for receiver: $receiverId');
    
    // ✅ ADD THIS LINE - Initialize CallManager with current user ID
    _callManager.initialize(widget.currentUserId);
    print('🔍 DEBUG: CallManager initialized');

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .get();

    if (!userDoc.exists) {
      print('❌ DEBUG: User document not found');
      return;
    }

    final userName = userDoc.data()?['name'] ?? 'Utilisateur';
    print('🔍 DEBUG: Starting call as: $userName');

    final result = await _callManager.startCall(
      callerId: widget.currentUserId,
      receiverId: receiverId,
      callerName: userName,
      receiverName: widget.chat.name,
    );

    print('🔍 DEBUG: CallManager.startCall result: ${result.success}');
    print('🔍 DEBUG: Call ID: ${result.callId}');
    print('🔍 DEBUG: Error message: ${result.errorMessage}');

    if (result.success && mounted) {
      print('✅ DEBUG: Call started successfully, navigating to CallScreen');
      
      // Navigate to CallScreen - no need to pass callService anymore
      final callDoc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(result.callId)
          .get();

      if (callDoc.exists) {
        final callData = CallData.fromMap(callDoc.data()!);
        print('✅ DEBUG: Call data retrieved, navigating...');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallScreen(
              callData: callData,
              isIncoming: false,
              currentUserId: widget.currentUserId,
            ),
          ),
        );
      } else {
        print('❌ DEBUG: Call document not found in Firestore');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: Call document not found')),
        );
      }
    } else {
      print('❌ DEBUG: Call failed: ${result.errorMessage}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${result.errorMessage}')),
      );
    }
  } catch (e) {
    print('❌ DEBUG: Error in _initiateCall: $e');
    print('❌ DEBUG: Stack trace: ${e.toString()}');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Erreur lors de l\'appel: $e')));
  }
}

  // CHANGED: Updated incoming call listener
void _listenForIncomingCalls() {
  FirebaseFirestore.instance
      .collection('calls')
      .where('receiverId', isEqualTo: widget.currentUserId)
      .where('status', isEqualTo: 'ringing')
      .snapshots()
      .listen((snapshot) {
        for (final doc in snapshot.docChanges) {
          if (doc.type == DocumentChangeType.added) {
            final callData = CallData.fromMap(
              doc.doc.data() as Map<String, dynamic>,
            );

            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => IncomingCallScreen(
                    callData: callData,
                    currentUserId: widget.currentUserId, 
                  ),
                ),
              );
            }
          }
        }
      });
}

  // Méthode helper pour l'état de chargement
  Widget _buildUserInfoLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.chat.name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 2),
        Text(
          'Chargement...',
          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildUserInfoOffline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.chat.name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          'Hors ligne',
          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  String _getLastSeenText(dynamic lastSeen) {
    if (lastSeen == null) return 'Hors ligne';

    try {
      final lastSeenTime = lastSeen is Timestamp
          ? lastSeen.toDate()
          : DateTime.fromMillisecondsSinceEpoch(lastSeen);
      final now = DateTime.now();
      final difference = now.difference(lastSeenTime);

      if (difference.inSeconds < 60) return 'En ligne récemment';
      if (difference.inMinutes < 1) return 'À l\'instant';
      if (difference.inMinutes < 60)
        return 'Il y a ${difference.inMinutes} min';
      if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
      if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
      return 'Il y a ${(difference.inDays / 7).floor()} sem';
    } catch (e) {
      print('Erreur formatage lastSeen: $e');
      return 'Hors ligne';
    }
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
      padding: const EdgeInsets.all(12),
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
              onPressed: _showAttachmentOptions,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tapez un message...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      onSubmitted: (t) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.emoji_emotions,
                      color: AppTheme.textSecondary,
                    ),
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
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, size: 20),
              color: Colors.white,
              onPressed: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isRecording ? Colors.redAccent : AppTheme.cardDark,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isRecording ? Icons.mic_off : Icons.mic,
                color: Colors.white,
                size: 20,
              ),
              onPressed: kIsWeb ? null : _toggleRecording,
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

      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

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
      await _chatService.updateLastMessage(
        '📷 Image',
        widget.currentUserId,
        userName,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image envoyée')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur image: $e')));
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );
      if (result == null) return;

      final platformFile = result.files.single;
      Uint8List? bytes = platformFile.bytes;
      if (bytes == null && platformFile.path != null) {
        final f = File(platformFile.path!);
        bytes = await f.readAsBytes();
      }
      if (bytes == null) throw Exception('Impossible de lire le fichier');

      final base64File = base64Encode(bytes);
      final fileName = platformFile.name;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

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
      await _chatService.updateLastMessage(
        '📎 Fichier: $fileName',
        widget.currentUserId,
        userName,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('📎 Fichier envoyé: $fileName')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur envoi fichier: $e')));
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (!_isRecording) {
        final tempDir = await getTemporaryDirectory();
        final filePath =
            '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

        await _recorder.startRecorder(toFile: filePath, codec: Codec.aacADTS);

        setState(() => _isRecording = true);
        return;
      }

      final path = await _recorder.stopRecorder();
      setState(() => _isRecording = false);

      if (path == null) return;

      final bytes = await File(path).readAsBytes();
      final base64Audio = base64Encode(bytes);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

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
        'Message vocal',
        widget.currentUserId,
        userName,
      );

      if (!kIsWeb) {
        File(path).delete();
      }
    } catch (e) {
      print('Audio error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur enregistrement: $e')));
    }
  }

  Future<void> _saveAndOpenFile(Message message) async {
    try {
      final base64 = message.mediaUrl ?? '';
      if (base64.isEmpty) return;
      final bytes = base64Decode(base64);
      final fileName = message.text.isNotEmpty
          ? message.text
          : 'file_${DateTime.now().millisecondsSinceEpoch}';

      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fichier prêt: $fileName - Utilisez le menu de votre navigateur pour enregistrer',
            ),
            duration: const Duration(seconds: 5),
          ),
        );

        _downloadFileWeb(bytes, fileName);
      } else {
        final tmpPath = Directory.systemTemp.path;
        final filePath = p.join(tmpPath, fileName);
        final f = File(filePath);
        await f.writeAsBytes(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fichier sauvegardé: $filePath')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur ouverture fichier: $e')));
    }
  }

  void _downloadFileWeb(Uint8List bytes, String fileName) {
    final base64 = base64Encode(bytes);
    final dataUrl = 'data:application/octet-stream;base64,$base64';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Téléchargez le fichier: $fileName'),
        action: SnackBarAction(
          label: 'Ouvrir',
          onPressed: () {
            print('Download file: $fileName');
          },
        ),
      ),
    );
  }

  // ---------- UI Helpers ----------

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
            style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
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
        height: 220,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary,
                borderRadius: BorderRadius.circular(2),
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
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                if (!kIsWeb)
                  _buildAttachmentOption(
                    icon: Icons.camera_alt,
                    label: 'Caméra',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage(ImageSource.camera);
                    },
                  ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Fichier',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendFile();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

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
      await _chatService.updateLastMessage(
        text,
        widget.currentUserId,
        userName,
      );

      _messageController.clear();
      if (_showEmoji) setState(() => _showEmoji = false);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur envoi message: $e')));
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

// Separate widget for better performance
// In ChatScreen - Update the MessageBubble usage
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;
  final VoidCallback onPlayAudio;
  final VoidCallback onOpenFile;
  final VoidCallback? onCallTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.onPlayAudio,
    required this.onOpenFile,
    this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    // Use the new helper methods
    if (message.isCallMessage) {
      return _buildCallMessage();
    }

    Widget content;
    bool isMediaMessage = false;

    bool isAudioMessage = message.type == MessageType.audio ||
        (message.mediaUrl != null &&
            message.mediaUrl!.isNotEmpty &&
            (message.text.contains('🎤') || message.text.isEmpty));

    if (message.type == MessageType.image && (message.mediaUrl?.isNotEmpty ?? false)) {
      isMediaMessage = true;
      final bytes = base64Decode(message.mediaUrl!);
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, height: 200, width: 200, fit: BoxFit.cover),
      );
    } else if (message.type == MessageType.file && (message.mediaUrl?.isNotEmpty ?? false)) {
      isMediaMessage = true;
      content = GestureDetector(
        onTap: onOpenFile,
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
                  message.text.isEmpty ? 'Fichier' : message.text,
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (isAudioMessage && (message.mediaUrl?.isNotEmpty ?? false)) {
      isMediaMessage = true;
      content = _buildAudioPlayer();
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.secondaryGradient,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),

          if (isMediaMessage) ...[
            Flexible(
              child: Column(
                crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 8),
                      child: Text(
                        message.senderName,
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  content,
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _formatMessageTime(message.timestamp),
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
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
                  boxShadow: isCurrentUser
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryCyan.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    content,
                    const SizedBox(height: 6),
                    Text(
                      _formatMessageTime(message.timestamp),
                      style: GoogleFonts.inter(
                        color: isCurrentUser ? Colors.white70 : AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (isCurrentUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // Updated call message builder
  Widget _buildCallMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardDark.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: message.isMissedCall ? Colors.red.withOpacity(0.5) : AppTheme.primaryCyan.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                message.isMissedCall ? Icons.call_missed : Icons.call,
                color: message.isMissedCall ? Colors.red : AppTheme.primaryCyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.isMissedCall ? 'Appel manqué' : 'Appel audio',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (message.callDuration > 0)
                    Text(
                      'Durée: ${message.callDuration}s',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    _formatMessageTime(message.timestamp),
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              if (onCallTap != null && message.isMissedCall) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onCallTap,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: const Icon(
                      Icons.call,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return GestureDetector(
      onTap: onPlayAudio,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryCyan.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message vocal',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Tap to play',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) return 'Maintenant';
    if (difference.inHours < 1) return '${difference.inMinutes}min';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}
