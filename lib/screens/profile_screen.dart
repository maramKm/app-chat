import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:app_chat/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:app_chat/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService = AuthService();

  String profileImage = '';
  Map<String, dynamic> userProfile = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      setState(() {
        userProfile = doc.data()!;
        profileImage = userProfile['profileImageBase64'] ?? '';
      });
    }
  }

  Future<void> _updateUserProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update(data);
    setState(() => userProfile.addAll(data));
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50, // réduit la taille
    );

    if (image != null) {
      // Lire les octets directement depuis XFile
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      await _updateUserProfile({'profileImageBase64': base64Image});
      setState(() => profileImage = base64Image);
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return Center(
        child: Text(
          'No user logged in',
          style: GoogleFonts.orbitron(color: Colors.white),
        ),
      );
    }

    return Container(
      color: AppTheme.darkBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 32),
            _buildProfileInfo(),
            const SizedBox(height: 32),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: profileImage.isEmpty ? AppTheme.primaryGradient : null,
                image: profileImage.isNotEmpty
                    ? DecorationImage(
                  image: MemoryImage(base64Decode(profileImage)), // ← ici
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: profileImage.isEmpty
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,

            ),
            Container(
              width: 40,
              height: 40,
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
                icon: const Icon(Icons.camera_alt, size: 20),
                color: Colors.white,
                onPressed: _pickProfileImage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          userProfile['name'] ?? '',
          style: GoogleFonts.orbitron(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          userProfile['bio'] ?? 'No bio available',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryCyan.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryCyan),
          ),
          child: Text(
            userProfile['status'] ?? 'Available',
            style: GoogleFonts.inter(
              color: AppTheme.primaryCyan,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildInfoItem(
            icon: Icons.person,
            title: 'Name',
            value: userProfile['name'] ?? '',
            onTap: () => _editField('Name', 'name'),
          ),
          const Divider(color: AppTheme.textSecondary),
          _buildInfoItem(
            icon: Icons.email,
            title: 'Email',
            value: userProfile['email'] ?? '',
            onTap: () => _editField('Email', 'email'),
          ),
          const Divider(color: AppTheme.textSecondary),
          _buildInfoItem(
            icon: Icons.phone,
            title: 'Phone',
            value: userProfile['phone'] ?? '',
            onTap: () => _editField('Phone', 'phone'),
          ),
          const Divider(color: AppTheme.textSecondary),
          _buildInfoItem(
            icon: Icons.info,
            title: 'Bio',
            value: userProfile['bio'] ?? '',
            onTap: () => _editField('Bio', 'bio'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: AppTheme.textSecondary,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        value,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.edit, color: Colors.cyan, size: 20),
      onTap: onTap,
    );
  }

  void _editField(String fieldName, String fieldKey) {
    final controller = TextEditingController(text: userProfile[fieldKey] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text('Edit $fieldName', style: GoogleFonts.orbitron(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your $fieldName',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateUserProfile({fieldKey: controller.text});
            },
            child: Text('Save', style: GoogleFonts.inter(color: AppTheme.primaryCyan)),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    final user = _auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withOpacity(0.8), Colors.orange.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextButton(
        onPressed: _confirmLogout,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Logout',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text('Logout', style: GoogleFonts.orbitron(color: Colors.white)),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
            },
            child: Text('Logout', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}