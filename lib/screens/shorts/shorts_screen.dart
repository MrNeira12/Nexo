import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

class NexoShortsScreen extends StatefulWidget {
  final bool isActive; 
  final Query? customQuery; 
  final bool showBackButton; 
  
  const NexoShortsScreen({
    super.key, 
    this.isActive = true, 
    this.customQuery,
    this.showBackButton = false,
  });

  @override
  State<NexoShortsScreen> createState() => _NexoShortsScreenState();
}

class _NexoShortsScreenState extends State<NexoShortsScreen> {
  final PageController _pageController = PageController();
  int _focusedIndex = 0;

  // Función de carga (Mantenida por lógica interna, pero UI removida de esta pantalla)
  Future<void> _uploadVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
      final String realName = userDoc.data()?['name'] ?? user?.displayName ?? 'Usuario';
      
      final videoId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final ref = FirebaseStorage.instance.ref().child('shorts').child('$videoId.mp4');
      await ref.putFile(File(video.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('shorts').doc(videoId).set({
        'url': url,
        'authorName': realName,
        'authorId': user?.uid,
        'title': 'Lección rápida educativa',
        'likes': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Video subido con éxito a Nexo!"), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al subir: $e"), behavior: SnackBarBehavior.floating));
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
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
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _focusedIndex = index % actualCount;
                  });
                },
                itemCount: 10000, 
                itemBuilder: (context, index) {
                  final int realIndex = index % actualCount;
                  final data = docs[realIndex].data() as Map<String, dynamic>?;
                  if (data == null) return const SizedBox.shrink();
                  
                  final id = docs[realIndex].id;
                  final bool isVideoActive = widget.isActive && (_focusedIndex == realIndex);
                  
                  return VideoPost(
                    videoId: id, 
                    videoData: data, 
                    isActive: isVideoActive,
                    key: ValueKey("$id-$index"),
                  );
                },
              );
            },
          ),
          
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
  bool _isSpeedUp = false;
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hasError = true);
      });
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Eliminado de guardados"), behavior: SnackBarBehavior.floating));
      }
    } else {
      await ref.set(widget.videoData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guardado en tu perfil de Nexo"), behavior: SnackBarBehavior.floating));
      }
    }
    setState(() => _isSaved = !_isSaved);
  }

  // Lógica de pausa simple optimizada
  void _handleTap() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    setState(() {
      _controller!.value.isPlaying ? _controller?.pause() : _controller?.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String authorName = widget.videoData['authorName'] ?? 'Usuario';
    final colors = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Offset ajustado para no interferir con la barra de navegación moderna
    final contentBottomOffset = 85 + bottomPadding;

    if (_hasError) {
      return const Center(child: Text("Error al cargar este video", style: TextStyle(color: Colors.white)));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _handleTap,
          onLongPressStart: (_) {
            setState(() => _isSpeedUp = true);
            _controller?.setPlaybackSpeed(2.0);
          },
          onLongPressEnd: (_) {
            setState(() => _isSpeedUp = false);
            _controller?.setPlaybackSpeed(1.0);
          },
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

        // Indicador de 2x Velocidad
        if (_isSpeedUp)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fast_forward, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text("2X Velocidad", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (_controller != null && !_controller!.value.isPlaying && _controller!.value.isInitialized)
          Center(
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  color: Colors.white.withOpacity(0.05),
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

        // Textos del Autor
        Positioned(
          bottom: contentBottomOffset,
          left: 20,
          right: 80, 
          child: RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("@$authorName", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(widget.videoData['title'] ?? 'Lección Educativa', 
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),

        // Botones Laterales
        Positioned(
          right: 15,
          bottom: contentBottomOffset - 10,
          child: RepaintBoundary(
            child: Column(
              children: [
                _sideButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  label: "${(widget.videoData['likes'] as List?)?.length ?? 0}",
                  iconColor: _isLiked ? colors.primary : Colors.white,
                  onTap: _toggleLike,
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('shorts')
                      .doc(widget.videoId)
                      .collection('comments')
                      .snapshots(),
                  builder: (context, snap) {
                    final count = snap.hasData ? snap.data!.docs.length : 0;
                    return _sideButton(
                      icon: Icons.comment_rounded,
                      label: "$count",
                      onTap: () => _showComments(context),
                    );
                  }
                ),
                _sideButton(
                  icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  label: _isSaved ? "Guardado" : "Guardar",
                  onTap: _toggleSave,
                ),
                _sideButton(
                  icon: Icons.share,
                  label: "Compartir",
                  onTap: () {
                    Share.share("¡Mira este Nexo Short! ${widget.videoData['url']}");
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  // Línea delgada para definir mejor el botón sobre el video
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 0.5,
                  ),
                ),
                child: Icon(icon, color: iconColor ?? color, size: 24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
              height: MediaQuery.of(context).size.height * 0.55,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10)),
                  ),
                  const Text("Comentarios", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  
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
                          physics: const BouncingScrollPhysics(),
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
                  
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                              hintText: "Escribe un comentario...",
                              hintStyle: const TextStyle(fontSize: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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