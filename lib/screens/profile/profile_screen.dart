import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
// Importamos la pantalla de favoritos para poder navegar a ella en Nexo
import '../favorites/favorites_screen.dart';
// Importamos la nueva pantalla de carpeta de guardados
import 'saved_folder_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isUploading = false;

  // --- LÓGICA DE IMAGEN (Cámara y Galería) ---
  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50);

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('${user!.uid}.jpg');

      await ref.putFile(File(pickedFile.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'photoUrl': url,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Foto de perfil actualizada!"), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al subir foto: $e"), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la Galería'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- LÓGICA DE NOMBRE PERSONALIZABLE ---
  Future<void> _updateName() async {
    if (_nameController.text.trim().isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'name': _nameController.text.trim(),
      });
      setState(() => _isEditingName = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo actualizar el nombre"), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final String name = userData?['name'] ?? 'Usuario';
        final String? photoUrl = userData?['photoUrl'];

        if (!_isEditingName) _nameController.text = name;

        return Scaffold(
          backgroundColor: isDark ? Colors.black : colors.surface,
          body: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                title: const Text("Mi Perfil", style: TextStyle(fontWeight: FontWeight.bold)),
                elevation: 0,
                backgroundColor: isDark ? Colors.black : colors.surface,
                surfaceTintColor: Colors.transparent,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    tooltip: "Cerrar Sesión",
                    onPressed: () => FirebaseAuth.instance.signOut(),
                  )
                ],
              ),

              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                    child: Column(
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 70,
                                backgroundColor: colors.primary.withOpacity(0.1),
                                backgroundImage: photoUrl != null && photoUrl.isNotEmpty 
                                    ? NetworkImage(photoUrl) 
                                    : null,
                                child: (photoUrl == null || photoUrl.isEmpty) 
                                    ? Icon(Icons.person, size: 85, color: colors.primary) 
                                    : null,
                              ),
                              if (_isUploading)
                                Positioned.fill(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 4,
                                child: GestureDetector(
                                  onTap: _showImageSourceActionSheet,
                                  child: CircleAvatar(
                                    backgroundColor: colors.primary,
                                    radius: 22,
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),

                        _isEditingName
                            ? Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _nameController,
                                      autofocus: true,
                                      decoration: const InputDecoration(
                                        labelText: "Tu nombre",
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    onPressed: _updateName, 
                                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 30)
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    name, 
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)
                                  ),
                                  IconButton(
                                    onPressed: () => setState(() => _isEditingName = true),
                                    icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                  ),
                                ],
                              ),
                        
                        const SizedBox(height: 8),
                        Text(
                          user?.email ?? "",
                          style: const TextStyle(color: Colors.grey),
                        ),

                        const Divider(height: 50, thickness: 0.5),

                        // BOTÓN DE MIS FAVORITOS (NUEVO ESTILO UNIFICADO)
                        _buildProfileCard(
                          context,
                          icon: Icons.favorite_rounded,
                          iconColor: Colors.redAccent,
                          title: "Mis Favoritos",
                          subtitle: "Tus audios, videos y libros guardados",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FavoritesScreen()),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // BOTÓN DE GUARDADOS (NUEVO ESTILO UNIFICADO)
                        _buildProfileCard(
                          context,
                          icon: Icons.bookmark_rounded,
                          iconColor: Colors.blueAccent,
                          title: "Guardados",
                          subtitle: "Tus shorts y carpetas de estudio",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SavedFolderScreen()),
                            );
                          },
                        ),

                        const SizedBox(height: 35),

                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Playlists Favoritas", 
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                ),
              ),

              // LISTA DE PLAYLISTS (Aislada para rendimiento)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final titles = ["Concentración Máxima", "Repaso de Historia"];
                      return RepaintBoundary(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                            tileColor: colors.surfaceContainerHighest.withOpacity(0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            leading: const Icon(Icons.playlist_play, color: Colors.blue, size: 30),
                            title: Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text("Sincronizado en la nube de Nexo", style: TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.cloud_done_outlined, size: 18, color: Colors.green),
                          ),
                        ),
                      );
                    },
                    childCount: 2,
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 130),
              ),
            ],
          ),
        );
      },
    );
  }

  // WIDGET ACTUALIZADO: Utiliza el mismo diseño de tarjetas del centro de creación
  Widget _buildProfileCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ICONO CON FONDO CIRCULAR DIFUMINADO
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 20),
              // TEXTOS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              // INDICADOR DE ACCIÓN
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.black26,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}