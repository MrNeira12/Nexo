import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

class EduShortsScreen extends StatefulWidget {
  final bool isActive; // Controla si la pestaña está visible para pausar/reproducir
  final Query? customQuery; // Permite pasar una consulta personalizada (ej: videos guardados)
  final bool showBackButton; // Muestra un botón de volver si se abre como sub-pantalla
  
  const EduShortsScreen({
    super.key, 
    this.isActive = true, 
    this.customQuery,
    this.showBackButton = false,
  });

  @override
  State<EduShortsScreen> createState() => _EduShortsScreenState();
}

class _EduShortsScreenState extends State<EduShortsScreen> {
  final PageController _pageController = PageController();
  int _focusedIndex = 0;

  // Función para abrir la cámara/galería y subir un video
  Future<void> _uploadVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video == null) return;

    // Mostrar un diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // Obtener el nombre real del usuario desde Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
      final String realName = userDoc.data()?['name'] ?? user?.displayName ?? 'Usuario';
      
      final videoId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // 1. Subir video a Storage
      final ref = FirebaseStorage.instance.ref().child('shorts').child('$videoId.mp4');
      await ref.putFile(File(video.path));
      final url = await ref.getDownloadURL();

      // 2. Guardar datos en Firestore
      await FirebaseFirestore.instance.collection('shorts').doc(videoId).set({
        'url': url,
        'authorName': realName,
        'authorId': user?.uid,
        'title': 'Lección rápida educativa',
        'likes': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context); // Cerrar cargando
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Video subido con éxito!")));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al subir: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Feed de Videos en tiempo real
          StreamBuilder<QuerySnapshot>(
            // Si hay una consulta personalizada (ej: de la carpeta guardados), la usamos.
            // Si no, usamos el feed global por defecto.
            stream: widget.customQuery?.snapshots() ?? FirebaseFirestore.instance
                .collection('shorts')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Error al cargar videos", style: TextStyle(color: Colors.white)));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final docs = snapshot.data!.docs;
              
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.video_library_outlined, color: Colors.white24, size: 80),
                      const SizedBox(height: 16),
                      const Text("No hay videos disponibles", style: TextStyle(color: Colors.white70, fontSize: 18)),
                      if (widget.showBackButton)
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          label: const Text("Volver", style: TextStyle(color: Colors.white)),
                        )
                    ],
                  ),
                );
              }

              final int actualCount = docs.length;

              return PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    // Calculamos el índice real basado en el total de documentos
                    _focusedIndex = index % actualCount;
                  });
                },
                // Usamos un número muy grande para simular un loop infinito
                itemCount: 10000, 
                itemBuilder: (context, index) {
                  // Mapeamos el índice del PageView al índice real de los datos
                  final int realIndex = index % actualCount;

                  final data = docs[realIndex].data() as Map<String, dynamic>?;
                  if (data == null) return const SizedBox.shrink();
                  
                  final id = docs[realIndex].id;
                  // El video está activo si la pestaña está activa y coincide con el índice visual actual
                  final bool isVideoActive = widget.isActive && (_focusedIndex == realIndex);
                  
                  return VideoPost(
                    videoId: id, 
                    videoData: data, 
                    isActive: isVideoActive,
                    // Añadimos el index a la ValueKey para evitar conflictos de estado en el loop
                    key: ValueKey("$id-$index"),
                  );
                },
              );
            },
          ),
          
          // Botón de subir (Solo lo mostramos en el feed principal, no en guardados)
          if (!widget.showBackButton)
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.add_a_photo, color: Colors.white, size: 28),
                onPressed: _uploadVideo,
              ),
            ),

          // Botón de volver (Solo si venimos de la carpeta de guardados)
          if (widget.showBackButton)
            Positioned(
              top: 50,
              left: 20,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.white.withOpacity(0.2),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class VideoPost extends StatefulWidget {
  final String videoId;
  final Map<String, dynamic> videoData;
  final bool isActive;
  const VideoPost({
    super.key, 
    required this.videoId, 
    required this.videoData,
    required this.isActive,
  });

  @override
  State<VideoPost> createState() => _VideoPostState();
}

class _VideoPostState extends State<VideoPost> {
  VideoPlayerController? _controller;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _hasError = false;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _initializeController();
    _isLiked = (widget.videoData['likes'] as List?)?.contains(user?.uid) ?? false;
    _checkIfSaved();
  }

  void _initializeController() {
    final String? url = widget.videoData['url'];
    if (url == null || url.isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          if (widget.isActive) _controller?.play();
          _controller?.setLooping(true);
        }
      }).catchError((error) {
        if (mounted) setState(() => _hasError = true);
      });
  }

  void _checkIfSaved() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('saved_shorts')
        .doc(widget.videoId)
        .get();
    if (mounted) {
      setState(() {
        _isSaved = doc.exists;
      });
    }
  }

  @override
  void didUpdateWidget(covariant VideoPost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (widget.isActive && !oldWidget.isActive) {
      _controller?.seekTo(Duration.zero);
      _controller?.play();
    } else if (!widget.isActive) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleLike() {
    final ref = FirebaseFirestore.instance.collection('shorts').doc(widget.videoId);
    if (_isLiked) {
      ref.update({'likes': FieldValue.arrayRemove([user?.uid])});
    } else {
      ref.update({'likes': FieldValue.arrayUnion([user?.uid])});
    }
    setState(() => _isLiked = !_isLiked);
  }

  void _toggleSave() async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .collection('saved_shorts')
        .doc(widget.videoId);

    if (_isSaved) {
      await ref.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Eliminado de guardados")));
      }
    } else {
      await ref.set(widget.videoData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guardado en tu perfil")));
      }
    }
    setState(() => _isSaved = !_isSaved);
  }

  void _handleTap() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _controller!.value.isPlaying ? _controller?.pause() : _controller?.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String authorName = widget.videoData['authorName'] ?? 'Usuario';

    if (_hasError) {
      return const Center(child: Text("Error al cargar este video", style: TextStyle(color: Colors.white)));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Reproductor de Video Full Screen
        GestureDetector(
          onTap: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: (_controller != null && _controller!.value.isInitialized)
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),

        // Icono de Pausa Moderno con Blur
        if (_controller != null && !_controller!.value.isPlaying && _controller!.value.isInitialized)
          Center(
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  color: Colors.white.withOpacity(0.2),
                  child: const Icon(Icons.play_arrow_rounded, size: 50, color: Colors.white),
                ),
              ),
            ),
          ),

        IgnorePointer(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
                stops: [0.0, 0.4],
              ),
            ),
          ),
        ),

        // Info del Autor
        Positioned(
          bottom: 40,
          left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("@$authorName", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(widget.videoData['title'] ?? 'Lección Educativa', 
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),

        // Botones Laterales
        Positioned(
          right: 15,
          bottom: 100,
          child: Column(
            children: [
              // LIKE BUTTON
              _sideButton(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                label: "${(widget.videoData['likes'] as List?)?.length ?? 0}",
                iconColor: _isLiked ? Colors.red : Colors.white,
                onTap: _toggleLike,
              ),
              // COMMENT BUTTON
              _sideButton(
                icon: Icons.comment_rounded,
                label: "Comentarios",
                onTap: () => _showComments(context),
              ),
              // SAVE BUTTON (Toggle con icono dinámico)
              _sideButton(
                icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                label: _isSaved ? "Guardado" : "Guardar",
                onTap: _toggleSave,
              ),
              // SHARE BUTTON
              _sideButton(
                icon: Icons.share,
                label: "Compartir",
                onTap: () {
                  Share.share("¡Mira este EduShort! ${widget.videoData['url']}");
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget de botón lateral con efecto Glassmorphism (Blur + Transparencia)
  Widget _sideButton({
    required IconData icon, 
    required String label, 
    Color color = Colors.white, 
    Color? iconColor,
    required VoidCallback onTap
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.white.withOpacity(0.15),
                child: Icon(icon, color: iconColor ?? color, size: 24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
      ],
    );
  }

  void _showComments(BuildContext context) {
    final theme = Theme.of(context);
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.5,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10)),
                  ),
                  const Text("Comentarios", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('shorts')
                          .doc(widget.videoId)
                          .collection('comments')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text("Aún no hay comentarios. ¡Sé el primero!"));
                        }
                        
                        return ListView.builder(
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final commentData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person, size: 20)),
                              title: Text(
                                commentData['userName'] ?? 'Usuario',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                commentData['text'] ?? '',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          decoration: InputDecoration(
                            hintText: "Escribe un comentario...",
                            hintStyle: const TextStyle(fontSize: 14),
                            border: const OutlineInputBorder(),
                            fillColor: theme.colorScheme.surfaceContainerHighest,
                            filled: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.send),
                        color: theme.colorScheme.primary,
                        onPressed: () async {
                          if (commentController.text.isNotEmpty) {
                            final String text = commentController.text.trim();
                            commentController.clear();
                            
                            final userDoc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
                            final String currentName = userDoc.data()?['name'] ?? user?.displayName ?? 'Anónimo';
                            
                            await FirebaseFirestore.instance
                                .collection('shorts')
                                .doc(widget.videoId)
                                .collection('comments')
                                .add({
                              'userId': user?.uid,
                              'userName': currentName,
                              'text': text,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          }
                        },
                      )
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}