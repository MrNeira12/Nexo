import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UploadBookScreen extends StatefulWidget {
  const UploadBookScreen({super.key});

  @override
  State<UploadBookScreen> createState() => _UploadBookScreenState();
}

class _UploadBookScreenState extends State<UploadBookScreen> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  
  File? _pdfFile;
  File? _coverImage;
  bool _isLoading = false;
  double _uploadProgress = 0;

  /// Selecciona el archivo PDF desde el almacenamiento del dispositivo
  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _pdfFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      _showSnackBar("Error al seleccionar el PDF: $e");
    }
  }

  /// Selecciona la imagen de portada
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 70, // Optimización para no saturar el Storage
      );
      if (pickedFile != null) {
        setState(() => _coverImage = File(pickedFile.path));
      }
    } catch (e) {
      _showSnackBar("Error al seleccionar la portada: $e");
    }
  }

  /// Proceso de subida dual: Archivo Físico (Storage) + Metadatos (Firestore)
  Future<void> _uploadBook() async {
    if (_titleController.text.isEmpty || _authorController.text.isEmpty || _pdfFile == null) {
      _showSnackBar("Por favor completa los campos y selecciona el PDF.");
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      String? pdfUrl;
      String? coverUrl;

      // 1. Subir el archivo PDF a Firebase Storage
      final String pdfName = 'book_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfRef = FirebaseStorage.instance.ref().child('books_files').child(pdfName);
      
      final uploadTask = pdfRef.putFile(_pdfFile!);
      
      // Escuchamos el progreso de la subida del PDF
      uploadTask.snapshotEvents.listen((snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      await uploadTask;
      pdfUrl = await pdfRef.getDownloadURL();

      // 2. Subir la Portada si el usuario seleccionó una
      if (_coverImage != null) {
        final String imgName = 'cover_book_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imgRef = FirebaseStorage.instance.ref().child('books_covers').child(imgName);
        await imgRef.putFile(_coverImage!);
        coverUrl = await imgRef.getDownloadURL();
      }

      // 3. Guardar metadatos en Firestore
      // Usamos la colección 'music' pero con type 'libro' para compatibilidad global
      await FirebaseFirestore.instance.collection('music').add({
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'url': pdfUrl,
        'coverUrl': coverUrl ?? '',
        'type': 'libro', // Crucial para que el explorador sepa qué abrir
        'isYouTube': false,
        'uploaderId': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("¡Libro publicado con éxito en Nexo!");
      }
    } catch (e) {
      _showSnackBar("Error durante la publicación: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
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
        title: const Text("Publicar Libro PDF", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ÁREA DE PORTADA (Vertical para libros)
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 240,
                width: 170,
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
                          Icon(Icons.add_photo_alternate_rounded, size: 50, color: colors.primary),
                          const SizedBox(height: 12),
                          const Text(
                            "Añadir Portada", 
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 35),

            // CAMPOS DE TEXTO
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Título del libro",
                prefixIcon: const Icon(Icons.menu_book_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _authorController,
              decoration: InputDecoration(
                labelText: "Autor / Escritor",
                prefixIcon: const Icon(Icons.person_pin_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 25),

            // SELECTOR DE ARCHIVO PDF
            SizedBox(
              width: double.infinity,
              height: 65,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickPDF,
                icon: Icon(
                  _pdfFile == null ? Icons.picture_as_pdf_rounded : Icons.check_circle, 
                  color: _pdfFile == null ? Colors.redAccent : Colors.green,
                ),
                label: Text(
                  _pdfFile == null ? "Seleccionar archivo PDF" : "Archivo PDF cargado",
                  style: TextStyle(
                    color: _pdfFile == null ? colors.onSurface : Colors.green, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  side: BorderSide(color: _pdfFile == null ? colors.outline : Colors.green),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ESTADO DE SUBIDA Y BOTÓN
            if (_isLoading)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 8,
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
                height: 60,
                child: FilledButton.icon(
                  onPressed: _uploadBook,
                  icon: const Icon(Icons.publish_rounded),
                  label: const Text(
                    "Publicar Libro", 
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)
                  ),
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