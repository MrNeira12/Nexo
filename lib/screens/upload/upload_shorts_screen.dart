import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as path;

class UploadShortsScreen extends StatefulWidget {
  const UploadShortsScreen({super.key});

  @override
  State<UploadShortsScreen> createState() => _UploadShortsScreenState();
}

class _UploadShortsScreenState extends State<UploadShortsScreen> {
  File? _videoFile;
  VideoPlayerController? _videoController;
  final TextEditingController _commentController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0;

  final ImagePicker _picker = ImagePicker();

  /// Abre la cámara o galería para capturar el video
  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60), // Límite de 60 segundos
      );

      if (pickedFile != null) {
        // Limpiar controlador anterior si existe
        await _videoController?.dispose();
        
        _videoFile = File(pickedFile.path);
        
        // Inicializar el controlador para la vista previa en la app
        _videoController = VideoPlayerController.file(_videoFile!)
          ..initialize().then((_) {
            setState(() {});
            _videoController?.setLooping(true);
            _videoController?.play();
          });
        
        setState(() {});
      }
    } catch (e) {
      _showSnackBar("Error al acceder a los medios: $e");
    }
  }

  /// Gestiona la subida del video y los metadatos a Firebase
  Future<void> _uploadShort() async {
    if (_videoFile == null || _commentController.text.trim().isEmpty) {
      _showSnackBar("Captura un video y añade una descripción");
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      // Generar nombre único basado en timestamp
      final String fileName = "${DateTime.now().millisecondsSinceEpoch}${path.extension(_videoFile!.path)}";
      
      // 1. Subida del archivo físico a Firebase Storage
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('shorts')
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(_videoFile!);

      // Monitoreo del progreso de subida
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      final TaskSnapshot downloadSnapshot = await uploadTask;
      final String videoUrl = await downloadSnapshot.ref.getDownloadURL();

      // 2. Registro de la información en Cloud Firestore
      await FirebaseFirestore.instance.collection('shorts').add({
        'userId': user?.uid,
        'authorName': user?.displayName ?? "Usuario Nexo",
        'url': videoUrl,
        'title': _commentController.text.trim(),
        'likes': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar("¡Tu short ha sido publicado!");
      if (mounted) Navigator.pop(context);

    } catch (e) {
      _showSnackBar("Error en la subida: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : colors.surface,
      appBar: AppBar(
        title: const Text("Crear Short", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Vista previa del video capturado
            AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
                ),
                child: _videoController != null && _videoController!.value.isInitialized
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_videoController!),
                            // Icono sutil de reproducción indicando que es preview
                            Icon(Icons.play_circle_fill, color: Colors.white.withOpacity(0.5), size: 50),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam_rounded, size: 60, color: colors.primary.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            "Graba una lección rápida",
                            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 24),

            // Selector de origen: Cámara o Galería
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isUploading ? null : () => _pickVideo(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text("Cámara"),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : () => _pickVideo(ImageSource.gallery),
                    icon: const Icon(Icons.video_collection_rounded),
                    label: const Text("Galería"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Campo de descripción o comentario
            TextField(
              controller: _commentController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: "Descripción del contenido",
                hintText: "¿De qué trata esta lección?",
                prefixIcon: const Icon(Icons.notes_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: colors.surfaceContainerHighest.withOpacity(0.1),
              ),
            ),

            const SizedBox(height: 32),

            // Estado de subida y botón principal
            if (_isUploading)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      minHeight: 10,
                      backgroundColor: colors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Subiendo: ${(_uploadProgress * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _uploadShort,
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text("Publicar en Nexo"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                ),
              ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}