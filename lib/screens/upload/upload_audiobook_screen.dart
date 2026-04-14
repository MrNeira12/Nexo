import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UploadAudiobookScreen extends StatefulWidget {
  const UploadAudiobookScreen({super.key});

  @override
  State<UploadAudiobookScreen> createState() => _UploadAudiobookScreenState();
}

class _UploadAudiobookScreenState extends State<UploadAudiobookScreen> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  
  File? _audioFile;
  File? _coverImage;
  bool _isLoading = false;
  double _uploadProgress = 0;

  // Seleccionar archivo de audio (MP3, WAV, etc)
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
      _showSnackBar("Error al seleccionar audio: $e");
    }
  }

  // Seleccionar imagen de portada
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
      _showSnackBar("Error al seleccionar portada: $e");
    }
  }

  // Proceso de subida unificado para Nexo
  Future<void> _uploadAudiobook() async {
    if (_titleController.text.isEmpty || _authorController.text.isEmpty || _audioFile == null) {
      _showSnackBar("Por favor completa el título, autor y selecciona el audio.");
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

      // 1. Subir Audio a Firebase Storage
      final String audioName = 'audiobook_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final audioRef = FirebaseStorage.instance.ref().child('audiobooks_files').child(audioName);
      
      final uploadTask = audioRef.putFile(_audioFile!);
      
      // Escuchar progreso (Solo para el archivo pesado que es el audio)
      uploadTask.snapshotEvents.listen((snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;
      audioUrl = await audioRef.getDownloadURL();

      // 2. Subir Portada si existe
      if (_coverImage != null) {
        final String imgName = 'cover_book_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imgRef = FirebaseStorage.instance.ref().child('audiobooks_covers').child(imgName);
        await imgRef.putFile(_coverImage!);
        coverUrl = await imgRef.getDownloadURL();
      }

      // 3. Guardar en la colección global de Nexo
      // Nota: Guardamos en 'music' o en una nueva colección según prefieras. 
      // Si usamos 'music' aparecerá en el reproductor actual automáticamente.
      await FirebaseFirestore.instance.collection('music').add({
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'url': audioUrl,
        'coverUrl': coverUrl ?? '',
        'type': 'audiolibro', // Tag para diferenciar en el feed
        'isYouTube': false,
        'uploaderId': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("¡Audiolibro publicado con éxito!");
      }
    } catch (e) {
      _showSnackBar("Error al subir contenido: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : colors.surface,
      appBar: AppBar(
        title: const Text("Subir Audiolibro", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Selector de Portada (Estilo Nexo)
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: 160,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.primary.withOpacity(0.2)),
                  image: _coverImage != null 
                      ? DecorationImage(image: FileImage(_coverImage!), fit: BoxFit.cover) 
                      : null,
                ),
                child: _coverImage == null 
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 50, color: colors.primary),
                          const SizedBox(height: 10),
                          const Text("Añadir Portada", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 40),

            TextField(
              controller: _titleController, 
              decoration: InputDecoration(
                labelText: "Título del libro", 
                prefixIcon: const Icon(Icons.book_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _authorController, 
              decoration: InputDecoration(
                labelText: "Narrador / Autor", 
                prefixIcon: const Icon(Icons.record_voice_over_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
              ),
            ),
            const SizedBox(height: 25),

            // Botón de selección de audio
            SizedBox(
              width: double.infinity,
              height: 65,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickAudio,
                icon: Icon(_audioFile == null ? Icons.audio_file_rounded : Icons.check_circle, 
                          color: _audioFile == null ? colors.primary : Colors.green),
                label: Text(
                  _audioFile == null ? "Seleccionar archivo de audio" : "Audio cargado correctamente",
                  style: TextStyle(color: _audioFile == null ? colors.onSurface : Colors.green, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  side: BorderSide(color: _audioFile == null ? colors.outline : Colors.green),
                ),
              ),
            ),

            const SizedBox(height: 40),

            if (_isLoading)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 12),
                  Text("Subiendo al Nexo: ${(_uploadProgress * 100).toStringAsFixed(0)}%"),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: _uploadAudiobook,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text("Publicar Audiolibro", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}