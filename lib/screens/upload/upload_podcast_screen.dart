import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UploadPodcastScreen extends StatefulWidget {
  const UploadPodcastScreen({super.key});

  @override
  State<UploadPodcastScreen> createState() => _UploadPodcastScreenState();
}

class _UploadPodcastScreenState extends State<UploadPodcastScreen> {
  final _titleController = TextEditingController();
  final _hostController = TextEditingController(); // Autor o Presentador
  
  File? _audioFile;
  File? _coverImage;
  bool _isLoading = false;
  double _uploadProgress = 0;

  // Seleccionar archivo de audio del Podcast
  Future<void> _pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _audioFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      _showSnackBar("Error al seleccionar audio del podcast: $e");
    }
  }

  // Seleccionar imagen de portada para el Podcast
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() => _coverImage = File(pickedFile.path));
      }
    } catch (e) {
      _showSnackBar("Error al seleccionar carátula: $e");
    }
  }

  // Lógica de subida unificada para la plataforma Nexo
  Future<void> _uploadPodcast() async {
    if (_titleController.text.isEmpty || _hostController.text.isEmpty || _audioFile == null) {
      _showSnackBar("Completa el título, el presentador y selecciona el audio.");
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      String? audioUrl;
      String? coverUrl;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // 1. Subir Audio del Podcast a Storage
      final String audioName = 'podcast_$timestamp.mp3';
      final audioRef = FirebaseStorage.instance.ref().child('podcasts_files').child(audioName);
      
      final uploadTask = audioRef.putFile(_audioFile!);
      
      // Monitoreo de progreso para la barra visual
      uploadTask.snapshotEvents.listen((snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      await uploadTask;
      audioUrl = await audioRef.getDownloadURL();

      // 2. Subir Portada personalizada
      if (_coverImage != null) {
        final String imgName = 'cover_pod_$timestamp.jpg';
        final imgRef = FirebaseStorage.instance.ref().child('podcasts_covers').child(imgName);
        await imgRef.putFile(_coverImage!);
        coverUrl = await imgRef.getDownloadURL();
      }

      // 3. Guardar metadatos en Firestore
      // Se integra en la colección 'music' con el type 'podcast' para que ExploreScreen lo filtre
      await FirebaseFirestore.instance.collection('music').add({
        'title': _titleController.text.trim(),
        'author': _hostController.text.trim(),
        'url': audioUrl,
        'coverUrl': coverUrl ?? '',
        'type': 'podcast', 
        'isYouTube': false,
        'uploaderId': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("¡Podcast publicado exitosamente en Nexo!");
      }
    } catch (e) {
      _showSnackBar("Error al publicar podcast: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : colors.surface,
      appBar: AppBar(
        title: const Text("Publicar Podcast", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            // Área de selección de carátula (Estilo Cuadrado Podcast)
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                width: 180,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: colors.primary.withOpacity(0.2)),
                  image: _coverImage != null 
                      ? DecorationImage(image: FileImage(_coverImage!), fit: BoxFit.cover) 
                      : null,
                ),
                child: _coverImage == null 
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic_external_on_rounded, size: 50, color: colors.primary),
                          const SizedBox(height: 10),
                          const Text("Portada del Podcast", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 40),

            TextField(
              controller: _titleController, 
              decoration: InputDecoration(
                labelText: "Título del episodio", 
                prefixIcon: const Icon(Icons.podcasts_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _hostController, 
              decoration: InputDecoration(
                labelText: "Presentador / Programa", 
                prefixIcon: const Icon(Icons.record_voice_over_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))
              ),
            ),
            const SizedBox(height: 30),

            // Selector de Archivo de Audio
            SizedBox(
              width: double.infinity,
              height: 65,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickAudio,
                icon: Icon(
                  _audioFile == null ? Icons.library_music_rounded : Icons.check_circle, 
                  color: _audioFile == null ? colors.primary : Colors.green
                ),
                label: Text(
                  _audioFile == null ? "Seleccionar Audio (MP3)" : "Audio listo para subir",
                  style: TextStyle(
                    color: _audioFile == null ? colors.onSurface : Colors.green,
                    fontWeight: FontWeight.bold
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: _audioFile == null ? colors.outline : Colors.green, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 45),

            if (_isLoading)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      minHeight: 10,
                      backgroundColor: colors.primary.withOpacity(0.1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Subiendo episodio: ${(_uploadProgress * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: _uploadPodcast,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text("Publicar ahora", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}