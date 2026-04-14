import 'package:flutter/material.dart';

// Importaciones de pantallas de subida específicas
import '../music/upload_music_screen.dart';
import 'upload_shorts_screen.dart'; 
import 'upload_audiobook_screen.dart'; 
import 'upload_book_screen.dart'; 
import 'upload_document_screen.dart';
import 'upload_podcast_screen.dart'; // Importación de la nueva pantalla de podcasts

class UploadSelectionScreen extends StatelessWidget {
  const UploadSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // LISTA DE OPCIONES INSTITUCIONALES DE NEXO
    final List<Map<String, dynamic>> uploadOptions = [
      {
        'title': 'Shorts',
        'subtitle': 'Videos educativos rápidos',
        'icon': Icons.play_circle_outline,
        'color': Colors.redAccent,
        'route': const UploadShortsScreen(), 
      },
      {
        'title': 'Música',
        'subtitle': 'Melodías para concentrarse',
        'icon': Icons.music_note,
        'color': Colors.pink,
        'route': const UploadMusicScreen(),
      },
      {
        'title': 'Audiolibros',
        'subtitle': 'Lecciones narradas',
        'icon': Icons.headphones,
        'color': Colors.blue,
        'route': const UploadAudiobookScreen(),
      },
      {
        'title': 'Podcast',
        'subtitle': 'Charlas y entrevistas',
        'icon': Icons.mic,
        'color': Colors.indigo,
        'route': const UploadPodcastScreen(), // Ruta habilitada
      },
      {
        'title': 'Cursos',
        'subtitle': 'Rutas de aprendizaje completo',
        'icon': Icons.school,
        'color': Colors.teal,
        'route': null,
      },
      {
        'title': 'Libros',
        'subtitle': 'Material de lectura PDF/ePub',
        'icon': Icons.menu_book,
        'color': Colors.green,
        'route': const UploadBookScreen(), 
      },
      {
        'title': 'Documentos',
        'subtitle': 'Ensayos y apuntes',
        'icon': Icons.description,
        'color': Colors.orange,
        'route': const UploadDocumentScreen(), 
      },
    ];

    return Scaffold(
      backgroundColor: isDark ? Colors.black : colors.surface,
      appBar: AppBar(
        title: const Text("Crear Contenido", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: RepaintBoundary(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: uploadOptions.length,
          itemBuilder: (context, index) {
            final option = uploadOptions[index];
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildUploadCard(
                context,
                title: option['title'],
                subtitle: option['subtitle'],
                icon: option['icon'],
                color: option['color'],
                onTap: () {
                  if (option['route'] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => option['route']),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("La subida de ${option['title']} estará disponible pronto"),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUploadCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.add_circle_outline_rounded,
                color: color.withOpacity(0.5),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}