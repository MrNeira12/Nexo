import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:image_picker/image_picker.dart';

class UploadMusicScreen extends StatefulWidget {
  const UploadMusicScreen({super.key});

  @override
  State<UploadMusicScreen> createState() => _UploadMusicScreenState();
}

class _UploadMusicScreenState extends State<UploadMusicScreen> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _youtubeUrlController = TextEditingController(); // Controlador para YouTube
  
  File? _audioFile;
  File? _coverImage;
  bool _isLoading = false;
  bool _isYouTube = false; // Estado para alternar entre Archivo y YouTube

  // Función para seleccionar el archivo de audio local (.mp3)
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al seleccionar audio: $e")),
        );
      }
    }
  }

  // Función para seleccionar la imagen de portada desde la galería
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        setState(() => _coverImage = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al seleccionar imagen: $e")),
        );
      }
    }
  }

  // Función para subir los archivos a Firebase Storage y los datos a Firestore
  Future<void> _upload() async {
    // Validaciones básicas
    if (_titleController.text.isEmpty || _authorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, ingresa el título y el autor")),
      );
      return;
    }

    if (!_isYouTube && _audioFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes seleccionar un archivo de audio")),
      );
      return;
    }

    if (_isYouTube && _youtubeUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, pega un enlace de YouTube")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? finalUrl;
      String? coverUrl;

      // 1. Manejo del contenido (Archivo o YouTube)
      if (_isYouTube) {
        finalUrl = _youtubeUrlController.text.trim();
      } else {
        final String audioName = 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final audioRef = FirebaseStorage.instance.ref().child('music_files').child(audioName);
        await audioRef.putFile(_audioFile!);
        finalUrl = await audioRef.getDownloadURL();
      }

      // 2. Subir Portada a Firebase Storage
      if (_coverImage != null) {
        final String imgName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imgRef = FirebaseStorage.instance.ref().child('music_covers').child(imgName);
        await imgRef.putFile(_coverImage!);
        coverUrl = await imgRef.getDownloadURL();
      }

      // 3. Guardar metadatos en Firestore
      await FirebaseFirestore.instance.collection('music').add({
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'url': finalUrl,
        'coverUrl': coverUrl ?? '',
        'isYouTube': _isYouTube, // Guardamos el tipo de origen
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Contenido publicado exitosamente!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error durante la carga: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nueva Publicación", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Switch de tipo de contenido
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text("Archivo"), icon: Icon(Icons.audiotrack_rounded)),
                ButtonSegment(value: true, label: Text("YouTube"), icon: Icon(Icons.link_rounded)),
              ],
              selected: {_isYouTube},
              onSelectionChanged: (val) => setState(() => _isYouTube = val.first),
            ),
            const SizedBox(height: 30),

            // Área de selección de Portada
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                width: 180,
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: colors.outline.withOpacity(0.3)),
                  image: _coverImage != null 
                      ? DecorationImage(image: FileImage(_coverImage!), fit: BoxFit.cover) 
                      : null,
                ),
                child: _coverImage == null 
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, size: 45, color: colors.primary),
                          const SizedBox(height: 8),
                          const Text("Portada del audio", style: TextStyle(fontSize: 12)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 35),

            TextField(
              controller: _titleController, 
              decoration: InputDecoration(
                labelText: "Título", 
                prefixIcon: const Icon(Icons.title_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _authorController, 
              decoration: InputDecoration(
                labelText: "Autor / Artista", 
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
              ),
            ),
            const SizedBox(height: 25),

            // Selector dinámico según el modo
            if (_isYouTube)
              TextField(
                controller: _youtubeUrlController,
                decoration: InputDecoration(
                  labelText: "Enlace de YouTube",
                  hintText: "Pega el link aquí...",
                  prefixIcon: const Icon(Icons.play_circle_fill),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _pickAudio,
                icon: Icon(_audioFile == null ? Icons.library_music_rounded : Icons.check_circle_rounded),
                label: Text(_audioFile == null ? "Seleccionar archivo MP3" : "Archivo seleccionado"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  backgroundColor: _audioFile == null ? colors.secondaryContainer : Colors.green.withOpacity(0.2),
                  foregroundColor: _audioFile == null ? colors.onSecondaryContainer : Colors.green[800],
                ),
              ),

            const SizedBox(height: 50),
            
            if (_isLoading) 
              const CircularProgressIndicator()
            else 
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary, 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: const Text("Publicar ahora", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}