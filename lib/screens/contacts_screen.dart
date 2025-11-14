import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_chat/theme/app_theme.dart';
import 'package:app_chat/models/user_model.dart';
import 'package:app_chat/models/chat_model.dart';
import 'package:app_chat/screens/chat_screen.dart';
import 'package:app_chat/services/friend_service.dart';
import 'package:app_chat/services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final FriendService _friendService = FriendService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  final List<User> contacts = [];
  int _pendingRequestsCount = 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSuggestionsTab(),
                  _buildFriendRequestsTab(),
                  _buildContactsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: TabBar(
        labelColor: AppTheme.primaryCyan,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.primaryCyan,
        tabs: [
          Tab(text: 'Suggestions'),
          Tab(
            child: StreamBuilder<QuerySnapshot>(
              stream: _friendService.getReceivedRequests(_currentUserId),
              builder: (context, snapshot) {
                int count = snapshot.data?.docs.length ?? 0;
                _pendingRequestsCount = count;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Demandes'),
                    if (count > 0) ...[
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryCyan,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          Tab(text: 'Contacts'),
        ],
      ),
    );
  }

  Widget _buildSuggestionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorWidget('Erreur de chargement');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }

        final allUsers = snapshot.data!.docs
            .where((doc) => doc.id != _currentUserId)
            .map((doc) => User.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();

        // 🔥 Écoute les relations en temps réel
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('friend_requests')
              .where(Filter.or(
            Filter('fromUserId', isEqualTo: _currentUserId),
            Filter('toUserId', isEqualTo: _currentUserId),
          ))
              .snapshots(),
          builder: (context, relationSnap) {
            if (!relationSnap.hasData) return _buildLoadingWidget();

            final relations =
            relationSnap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();

            // Liste finale visible
            final visibleUsers = <User>[];

            for (final user in allUsers) {
              final relation = relations.firstWhere(
                    (r) =>
                (r['fromUserId'] == _currentUserId && r['toUserId'] == user.id) ||
                    (r['toUserId'] == _currentUserId && r['fromUserId'] == user.id),
                orElse: () => {},
              );

              // ✅ afficher uniquement ceux sans relation "accepted"
              if (relation.isEmpty) {
                visibleUsers.add(user);
              } else if (relation['status'] == 'pending' ||
                  relation['status'] == 'rejected') {
                visibleUsers.add(user);
              }
            }

            if (visibleUsers.isEmpty) {
              return Center(
                child: Text(
                  'Aucune suggestion pour le moment',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary),
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: visibleUsers.length,
              itemBuilder: (context, index) {
                final user = visibleUsers[index];
                final relation = relations.firstWhere(
                      (r) =>
                  (r['fromUserId'] == _currentUserId && r['toUserId'] == user.id) ||
                      (r['toUserId'] == _currentUserId && r['fromUserId'] == user.id),
                  orElse: () => {},
                );

                String status = 'none';
                if (relation.isNotEmpty) {
                  if (relation['status'] == 'pending' &&
                      relation['fromUserId'] == _currentUserId) {
                    status = 'sent';
                  } else if (relation['status'] == 'pending' &&
                      relation['toUserId'] == _currentUserId) {
                    status = 'received';
                  }
                }

                return _buildSuggestionItem(user, status);
              },
            );
          },
        );
      },
    );
  }


  Widget _buildFriendRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _friendService.getReceivedRequests(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Erreur requests: ${snapshot.error}');
          return _buildErrorWidget('Erreur de chargement des demandes');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }

        final requests = snapshot.data!.docs;

        if (requests.isEmpty) {
          return _buildEmptyRequestsWidget();
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;

            return _buildFriendRequestItem(request.id, data);
          },
        );
      },
    );
  }

  Widget _buildContactsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _friendService.getFriendsUsers(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Erreur contacts: ${snapshot.error}');
          return _buildErrorWidget('Erreur de chargement des contacts');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }

        final friendsData = snapshot.data ?? [];

        if (friendsData.isEmpty) {
          return _buildEmptyContactsWidget();
        }

        return ListView(
          children: [
            _buildContactsHeader(friendsData.length),
            ...friendsData.map((friendData) {
              // On crée un User avec les infos correctes de l'autre utilisateur
              final user = User.fromMap({
                'id': friendData['id'],
                'name': friendData['name'],
                'email': friendData['email'],
                'profileImage': friendData['profileImage'],
                'isOnline': friendData['isOnline'],
                'lastSeen': friendData['lastSeen'],
              }, friendData['id']);

              return _buildContactItem(user);
            }).toList(),
          ],
        );
      },
    );
  }


  Widget _buildSuggestionItem(User user, String? status) {
    final String firstLetter = (user.name.isNotEmpty ? user.name[0] : '?').toUpperCase();

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          user.profileImage.isNotEmpty
              ? CircleAvatar(radius: 25, backgroundImage: NetworkImage(user.profileImage))
              : CircleAvatar(
            radius: 25,
            backgroundColor: AppTheme.primaryCyan.withOpacity(0.8),
            child: Text(firstLetter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name.isNotEmpty ? user.name : 'Utilisateur', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(user.email, style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (status == 'none' || status == null)
            ElevatedButton(
              onPressed: () => _sendFriendRequest(user),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          else if (status == 'sent')
            ElevatedButton(onPressed: null, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Invitation sent', style: TextStyle(color: Colors.white)))
          else if (status == 'received')
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () async {
                      final req = await FirebaseFirestore.instance
                          .collection('friend_requests')
                          .where('fromUserId', isEqualTo: user.id)
                          .where('toUserId', isEqualTo: _currentUserId)
                          .where('status', isEqualTo: 'pending')
                          .get();
                      if (req.docs.isNotEmpty) {
                        await _friendService.acceptFriendRequest(req.docs.first.id, req.docs.first.data());
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () async {
                      final req = await FirebaseFirestore.instance
                          .collection('friend_requests')
                          .where('fromUserId', isEqualTo: user.id)
                          .where('toUserId', isEqualTo: _currentUserId)
                          .where('status', isEqualTo: 'pending')
                          .get();
                      if (req.docs.isNotEmpty) {
                        await _friendService.rejectFriendRequest(req.docs.first.id);
                      }
                    },
                  ),
                ],
              ),
        ],
      ),
    );
  }



  Widget _buildFriendRequestItem(String requestId, Map<String, dynamic> data) {
    final fromUserInfo = data['fromUserInfo'] as Map<String, dynamic>;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple.withOpacity(0.3),
            AppTheme.primaryCyan.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: NetworkImage(fromUserInfo['profileImage']?.isNotEmpty == true
                    ? fromUserInfo['profileImage']
                    : 'https://i.pravatar.cc/150?img=${fromUserInfo['name']?.hashCode ?? 1 % 70}'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fromUserInfo['name'] ?? 'Utilisateur',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  fromUserInfo['email'] ?? '',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Il y a ${_formatTimestamp(data['timestamp'])}',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Bouton Accepter
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.check, color: Colors.white, size: 20),
                  onPressed: () => _acceptFriendRequest(requestId, data),
                ),
              ),
              SizedBox(width: 8),
              // Bouton Refuser
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => _rejectFriendRequest(requestId),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Contacts',
            style: GoogleFonts.orbitron(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Spacer(),
          Text(
            '$count amis',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(User user) {
    return ListTile(
      leading: Stack(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: NetworkImage(user.profileImage.isNotEmpty
                    ? user.profileImage
                    : 'https://i.pravatar.cc/150?img=${user.id.hashCode % 70}'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (user.isOnline)
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
        user.name,
        style: GoogleFonts.inter(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        user.isOnline ? 'En ligne' : 'Hors ligne',
        style: GoogleFonts.inter(
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.chat,
          color: Colors.white,
          size: 20,
        ),
      ),
      onTap: () => _startConversation(user),
      onLongPress: () async {
        // Confirmer la suppression
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Supprimer ce contact ?'),
            content: Text('Voulez-vous vraiment retirer ${user.name} de vos contacts ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Supprimer'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          try {
            await _friendService.removeFriend(
              userId: _currentUserId,
              friendId: user.id,
            );

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${user.name} a été supprimé de vos contacts'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
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
          SizedBox(height: 16),
          Text(
            'Chargement...',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 50),
            SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.red,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
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
      ),
    );
  }

  Widget _buildEmptyRequestsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_add, color: AppTheme.textSecondary.withOpacity(0.5), size: 80),
          SizedBox(height: 16),
          Text(
            'Aucune demande d\'ami',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Les demandes d\'ami apparaîtront ici',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyContactsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, color: AppTheme.textSecondary.withOpacity(0.5), size: 80),
          SizedBox(height: 16),
          Text(
            'Aucun contact',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ajoutez des amis pour commencer',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Méthodes d'actions
  void _sendFriendRequest(User user) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;

      final toUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .get();

      final toUserData = toUserDoc.data() as Map<String, dynamic>;

      await _friendService.sendFriendRequest(
        fromUserId: currentUser.uid,
        toUserId: user.id,
        fromUserInfo: {
          'name': currentUserData['name'] ?? currentUser.displayName ?? 'Utilisateur',
          'email': currentUserData['email'] ?? currentUser.email ?? '',
          'profileImage': currentUserData['profileImage'] ?? currentUser.photoURL ?? '',
        },
        toUserInfo: {
          'name': toUserData['name'] ?? user.name,
          'email': toUserData['email'] ?? user.email,
          'profileImage': toUserData['profileImage'] ?? user.profileImage,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demande envoyée à ${user.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  void _acceptFriendRequest(String requestId, Map<String, dynamic> data) async {
    try {
      await _friendService.acceptFriendRequest(requestId, data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demande acceptée !'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _rejectFriendRequest(String requestId) async {
    try {
      await _friendService.rejectFriendRequest(requestId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demande refusée'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startConversation(User user) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      final chat = await ChatService.getOrCreateChat(
        currentUserId: currentUserId,
        otherUserId: user.id,
        otherUserName: user.name, // ← C'est ce nom qui sera dans widget.chat.name
        otherUserProfileImage: user.profileImage,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chat: chat,
            currentUserId: currentUserId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) return 'à l\'instant';
    if (difference.inHours < 1) return 'il y a ${difference.inMinutes}min';
    if (difference.inDays < 1) return 'il y a ${difference.inHours}h';
    return 'il y a ${difference.inDays}j';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'quelques instants';

    try {
      final DateTime time = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inMinutes < 1) return 'quelques instants';
      if (difference.inHours < 1) return '${difference.inMinutes}min';
      if (difference.inDays < 1) return '${difference.inHours}h';
      return '${difference.inDays}j';
    } catch (e) {
      return 'quelques instants';
    }
  }
}