import 'package:flutter/material.dart';
import 'package:konvo/theme/app_theme.dart';
import 'package:konvo/services/friend_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final FriendService _friendService = FriendService();

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          userData["name"] ?? "Profile",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.cardDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: userData["profileImage"] != ""
                  ? NetworkImage(userData["profileImage"])
                  : null,
              child: userData["profileImage"] == ""
                  ? Text(
                      (userData["name"] ?? "?")[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 20),

            Text(
              userData["name"] ?? "",
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),

            Text(
              userData["email"] ?? "",
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () async {
                await _friendService.sendFriendRequest(
                  fromUserId: FirebaseAuth.instance.currentUser!.uid,
                  toUserId: userId,
                  fromUserInfo: {
                    'name': FirebaseAuth.instance.currentUser!.displayName ?? '',
                    'email': FirebaseAuth.instance.currentUser!.email ?? '',
                    'profileImage': FirebaseAuth.instance.currentUser!.photoURL ?? '',
                  },
                  toUserInfo: userData,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Friend request sent!")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text("Add Friend",
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
