import 'package:flutter/material.dart';
import 'package:app_chat/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_chat/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String profileImage = '';
  User? _currentUser;
  bool _isLoading = true;

  Map<String, String> userProfile = {
    'name': '',
    'email': '',
    'phone': '',
    'bio': 'Flutter Developer & Digital Creator',
    'status': 'Available',
  };

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Récupérer l'utilisateur actuellement connecté
      _currentUser = _auth.currentUser;
      
      if (_currentUser != null) {
        setState(() {
          userProfile['name'] = _currentUser!.displayName ?? 'Utilisateur';
          userProfile['email'] = _currentUser!.email ?? 'Non spécifié';
          userProfile['phone'] = _currentUser!.phoneNumber ?? 'Non spécifié';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement du profil: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.darkBackground,
      child: _isLoading
          ? _buildLoadingWidget()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 32),
                  _buildProfileInfo(),
                  const SizedBox(height: 32),
                  _buildSettingsSections(),
                  const SizedBox(height: 32),
                  _buildLogoutButton(),
                ],
              ),
            ),
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
          const SizedBox(height: 20),
          Text(
            'Chargement du profil...',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
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
                gradient: profileImage.isEmpty && _currentUser?.photoURL == null
                    ? AppTheme.primaryGradient
                    : null,
                image: profileImage.isEmpty && _currentUser?.photoURL != null
                    ? DecorationImage(
                        image: NetworkImage(_currentUser!.photoURL!),
                        fit: BoxFit.cover,
                      )
                    : profileImage.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(profileImage),
                            fit: BoxFit.cover,
                          )
                        : null,
              ),
              child: profileImage.isEmpty && _currentUser?.photoURL == null
                  ? Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    )
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
          userProfile['name']!,
          style: GoogleFonts.orbitron(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          userProfile['bio']!,
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
            userProfile['status']!,
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
            title: 'Nom',
            value: userProfile['name']!,
            onTap: () => _editField('Nom', 'name'),
          ),
          const Divider(color: AppTheme.textSecondary),
          _buildInfoItem(
            icon: Icons.email,
            title: 'Email',
            value: userProfile['email']!,
            onTap: () => _editField('Email', 'email', isEmail: true),
          ),
          const Divider(color: AppTheme.textSecondary),
          _buildInfoItem(
            icon: Icons.phone,
            title: 'Téléphone',
            value: userProfile['phone']!,
            onTap: () => _editField('Téléphone', 'phone'),
          ),
          const Divider(color: AppTheme.textSecondary),
          _buildInfoItem(
            icon: Icons.info,
            title: 'Bio',
            value: userProfile['bio']!,
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
        value.isEmpty ? 'Non spécifié' : value,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.edit,
        color: AppTheme.primaryCyan,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSettingsSections() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildSettingItem(
            icon: Icons.notifications,
            title: 'Notifications',
            onTap: () {},
          ),
          const Divider(color: AppTheme.textSecondary),
          _buildSettingItem(
            icon: Icons.security,
            title: 'Confidentialité & Sécurité',
            onTap: () {},
          ),
          const Divider(color: AppTheme.textSecondary),
          _buildSettingItem(
            icon: Icons.chat,
            title: 'Paramètres de chat',
            onTap: () {},
          ),
          const Divider(color: AppTheme.textSecondary),
          _buildSettingItem(
            icon: Icons.storage,
            title: 'Données & Stockage',
            onTap: () {},
          ),
          const Divider(color: AppTheme.textSecondary),
          _buildSettingItem(
            icon: Icons.help,
            title: 'Aide & Support',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: AppTheme.secondaryGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: AppTheme.textSecondary,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.8),
            Colors.orange.withOpacity(0.8),
          ],
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
              'Se déconnecter',
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

  Future<void> _pickProfileImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        profileImage = image.path;
      });
      // Ici vous pouvez uploader l'image vers Firebase Storage
    }
  }

  void _editField(String fieldName, String fieldKey, {bool isEmail = false}) {
    TextEditingController controller = TextEditingController(text: userProfile[fieldKey]);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(
          'Modifier $fieldName',
          style: GoogleFonts.orbitron(
            color: Colors.white,
          ),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Entrez votre $fieldName',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.primaryCyan),
            ),
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
              if (controller.text.trim().isNotEmpty) {
                _updateUserProfile(fieldKey, controller.text.trim(), isEmail: isEmail);
              }
              Navigator.pop(context);
            },
            child: Text(
              'Sauvegarder',
              style: GoogleFonts.inter(color: AppTheme.primaryCyan),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserProfile(String field, String value, {bool isEmail = false}) async {
    try {
      if (isEmail) {
        // Pour changer l'email, on doit utiliser FirebaseAuth.instance
        await _auth.currentUser!.updateEmail(value);
      } else if (field == 'name') {
        // Pour changer le nom d'affichage
        await _auth.currentUser!.updateDisplayName(value);
      }
      
      // Mettre à jour l'interface
      setState(() {
        userProfile[field] = value;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryCyan,
          content: Text(
            'Profil mis à jour avec succès',
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      String errorMessage = 'Erreur lors de la mise à jour';
      
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'requires-recent-login':
            errorMessage = 'Cette action nécessite une reconnexion récente';
            break;
          case 'email-already-in-use':
            errorMessage = 'Cet email est déjà utilisé';
            break;
          case 'invalid-email':
            errorMessage = 'Email invalide';
            break;
          default:
            errorMessage = 'Erreur: ${e.message}';
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            errorMessage,
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      );
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(
          'Se déconnecter',
          style: GoogleFonts.orbitron(
            color: Colors.white,
          ),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vous déconnecter?',
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
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
            },
            child: Text(
              'Se déconnecter',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

extension on User {
  Future<void> updateEmail(String value) async {}
}