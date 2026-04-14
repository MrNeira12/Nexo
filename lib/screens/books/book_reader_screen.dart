import 'dart:io';
import 'dart:ui'; // Necesario para el efecto de Blur
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class BookReaderScreen extends StatefulWidget {
  final String url;
  final String title;

  const BookReaderScreen({super.key, required this.url, required this.title});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  String? localPath;
  bool isReady = false;
  int totalPages = 0;
  int currentPage = 0;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _downloadFile();
  }

  /// Descarga el archivo PDF desde la URL de Firebase para visualizarlo localmente.
  Future<void> _downloadFile() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      final bytes = response.bodyBytes;
      
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/temp_book_${DateTime.now().millisecondsSinceEpoch}.pdf");

      await file.writeAsBytes(bytes, flush: true);
      
      if (mounted) {
        setState(() {
          localPath = file.path;
          isReady = true;
        });
      }
    } catch (e) {
      debugPrint("Error al descargar el documento: $e");
      if (mounted) {
        setState(() => hasError = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Permitimos que el cuerpo se extienda detrás del AppBar para que el blur funcione al hacer scroll
      extendBodyBehindAppBar: true, 
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AppBar(
              backgroundColor: (isDark ? Colors.black : Colors.white).withOpacity(0.2),
              elevation: 0,
              centerTitle: true,
              title: Text(
                widget.title, 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
              actions: [
                if (isReady && !hasError)
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Center(
                      child: Text(
                        "${currentPage + 1} / $totalPages", 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
                      )
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(ColorScheme colors) {
    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text("No se pudo cargar el documento"),
            TextButton(
              onPressed: () {
                setState(() {
                  hasError = false;
                  isReady = false;
                });
                _downloadFile();
              },
              child: const Text("Reintentar"),
            )
          ],
        ),
      );
    }

    if (!isReady) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text("Preparando tu lección...", style: TextStyle(color: colors.primary)),
          ],
        ),
      );
    }

    // Ajustamos el Padding para que el contenido comience justo debajo del AppBar pero sea visible el blur
    return Padding(
      padding: const EdgeInsets.only(top: kToolbarHeight + 10),
      child: PDFView(
        filePath: localPath,
        enableSwipe: true,
        swipeHorizontal: false, 
        autoSpacing: true,
        pageFling: true,
        onRender: (pages) => setState(() => totalPages = pages!),
        onPageChanged: (page, total) => setState(() => currentPage = page!),
        onError: (error) {
          setState(() => hasError = true);
          debugPrint(error.toString());
        },
        onPageError: (page, error) {
          debugPrint('$page: ${error.toString()}');
        },
      ),
    );
  }
}