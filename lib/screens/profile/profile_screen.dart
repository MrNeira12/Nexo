import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
// Importamos la pantalla de favoritos para poder navegar a ella
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
          const SnackBar(content: Text("¡Foto de perfil actualizada!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al subir foto: $e")),
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
        const SnackBar(content: Text("No se pudo actualizar el nombre")),
      );
    }
  }

  // Mantenemos la lógica de eliminar aunque se use en otra pantalla por si acaso
  Future<void> _removeSavedShort(String shortId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('saved_shorts')
          .doc(shortId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Eliminado de tus shorts guardados")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al eliminar")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                title: const Text("Mi Perfil"),
                elevation: 0,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    tooltip: "Cerrar Sesión",
                    onPressed: () => FirebaseAuth.instance.signOut(),
                  )
                ],
              ),

              SliverToBoxAdapter(
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
                                    color: Colors.black26,
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
                      
                      const SizedBox(height: 10),
                      Text(
                        user?.email ?? "",
                        style: const TextStyle(color: Colors.grey),
                      ),

                      const Divider(height: 50),

                      // BOTÓN DE MIS FAVORITOS
                      Card(
                        elevation: 0,
                        color: colors.surfaceContainerHighest.withOpacity(0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          leading: const Icon(Icons.favorite, color: Colors.red),
                          title: const Text("Mis Favoritos", style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text("Tus audios, videos y libros guardados"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FavoritesScreen()),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // BOTÓN DE GUARDADOS (Lleva a la carpeta principal de guardados)
                      Card(
                        elevation: 0,
                        color: colors.surfaceContainerHighest.withOpacity(0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          leading: const Icon(Icons.bookmark, color: Colors.blue),
                          title: const Text("Guardados", style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text("Tus shorts y carpetas de estudio"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SavedFolderScreen()),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 30),

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

              // LISTA DE PLAYLISTS
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final titles = ["Concentración Máxima", "Repaso de Historia"];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                          tileColor: colors.surfaceContainerHighest.withOpacity(0.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: const Icon(Icons.playlist_play, color: Colors.blue, size: 30),
                          title: Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text("Sincronizado en la nube"),
                          trailing: const Icon(Icons.cloud_done_outlined, size: 18, color: Colors.green),
                        ),
                      );
                    },
                    childCount: 2,
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
        );
      },
    );
  }
}