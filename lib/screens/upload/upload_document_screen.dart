import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdfx/pdfx.dart' as pdfr; // Importación para extracción automática

class UploadDocumentScreen extends StatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  final _titleController = TextEditingController();
  final _institutionController = TextEditingController();
  
  File? _pdfFile;
  File? _coverImage;
  bool _isLoading = false;
  double _uploadProgress = 0;

  // Seleccionar archivo PDF
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
      _showSnackBar("Error al seleccionar documento: $e");
    }
  }

  // Seleccionar imagen de portada manualmente
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
      if (pickedFile != null) {
        setState(() => _coverImage = File(pickedFile.path));
      }
    } catch (e) {
      _showSnackBar("Error al seleccionar miniatura: $e");
    }
  }

  // Lógica para extraer la primera página automáticamente
  Future<Uint8List?> _generateThumbnailFromPDF(File pdfFile) async {
    try {
      final document = await pdfr.PdfDocument.openFile(pdfFile.path);
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width * 1.5,
        height: page.height * 1.5,
        format: pdfr.PdfPageImageFormat.jpeg,
        quality: 70,
      );
      await page.close();
      await document.close();
      return pageImage?.bytes;
    } catch (e) {
      debugPrint("Error extrayendo miniatura: $e");
      return null;
    }
  }

  Future<void> _uploadDocument() async {
    if (_titleController.text.isEmpty || _pdfFile == null) {
      _showSnackBar("Por favor ingresa un título y selecciona el PDF.");
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      String pdfUrl = "";
      String coverUrl = "";

      // 1. Subir PDF a Storage
      final String pdfName = 'doc_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfRef = FirebaseStorage.instance.ref().child('documents_files').child(pdfName);
      
      final uploadTask = pdfRef.putFile(_pdfFile!);
      uploadTask.snapshotEvents.listen((snapshot) {
        if (mounted) {
          setState(() => _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });

      await uploadTask;
      pdfUrl = await pdfRef.getDownloadURL();

      // 2. Manejo de Portada/Miniatura
      if (_coverImage != null) {
        // Subir portada seleccionada manualmente
        final String imgName = 'cover_doc_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imgRef = FirebaseStorage.instance.ref().child('documents_covers').child(imgName);
        await imgRef.putFile(_coverImage!);
        coverUrl = await imgRef.getDownloadURL();
      } else {
        // EXTRACCIÓN AUTOMÁTICA si no hay portada manual
        final thumbnailBytes = await _generateThumbnailFromPDF(_pdfFile!);
        if (thumbnailBytes != null) {
          final String autoImgName = 'auto_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final autoImgRef = FirebaseStorage.instance.ref().child('documents_covers').child(autoImgName);
          
          // Aseguramos que se suban los bytes con el Content-Type correcto
          final metadata = SettableMetadata(contentType: 'image/jpeg');
          await autoImgRef.putData(thumbnailBytes, metadata);
          coverUrl = await autoImgRef.getDownloadURL();
        }
      }

      // 3. Guardar en Firestore (Aseguramos que el campo coverUrl exista siempre)
      await FirebaseFirestore.instance.collection('music').add({
        'title': _titleController.text.trim(),
        'author': _institutionController.text.trim().isEmpty 
            ? "Documento Nexo" 
            : _institutionController.text.trim(),
        'url': pdfUrl,
        'coverUrl': coverUrl, // Ahora garantizamos que se envíe como String (vacío si falló)
        'type': 'documento',
        'isYouTube': false,
        'uploaderId': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("¡Documento publicado exitosamente!");
      }
    } catch (e) {
      debugPrint("Error crítico en subida: $e");
      _showSnackBar("Error al subir documento: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : colors.surface,
      appBar: AppBar(
        title: const Text("Subir Documento", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Área de miniatura
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                width: 140,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: colors.primary.withOpacity(0.2)),
                  image: _coverImage != null 
                      ? DecorationImage(image: FileImage(_coverImage!), fit: BoxFit.cover) 
                      : null,
                ),
                child: _coverImage == null 
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.note_add_outlined, size: 50, color: Colors.orange),
                          SizedBox(height: 8),
                          Text("Miniatura Opcional", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ) 
                    : null,
              ),
            ),
            const SizedBox(height: 30),

            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Título del documento",
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _institutionController,
              decoration: InputDecoration(
                labelText: "Institución / Autor (Opcional)",
                prefixIcon: const Icon(Icons.account_balance_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 65,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickPDF,
                icon: Icon(
                  _pdfFile == null ? Icons.upload_file_rounded : Icons.check_circle, 
                  color: _pdfFile == null ? Colors.orange : Colors.green,
                ),
                label: Text(
                  _pdfFile == null ? "Seleccionar archivo PDF" : "Documento listo",
                  style: TextStyle(color: _pdfFile == null ? colors.onSurface : Colors.green),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),

            const SizedBox(height: 40),

            if (_isLoading)
              Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress, borderRadius: BorderRadius.circular(10)),
                  const SizedBox(height: 12),
                  Text("Procesando y publicando: ${(_uploadProgress * 100).toStringAsFixed(0)}%"),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: _uploadDocument,
                  icon: const Icon(Icons.cloud_done_rounded),
                  label: const Text("Publicar ahora", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange[800],
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