import 'package:flutter/material.dart';
import 'saved_shorts_screen.dart';

class SavedFolderScreen extends StatelessWidget {
  const SavedFolderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // DEFINICIÓN DE CARPETAS BASADA EN EL ESTILO INSTITUCIONAL
    final List<Map<String, dynamic>> folders = [
      {
        'title': 'Shorts',
        'subtitle': 'Videos cortos educativos',
        'icon': Icons.play_circle_outline,
        'color': Colors.redAccent,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SavedShortsScreen()),
            ),
      },
      {
        'title': 'Música',
        'subtitle': 'Melodías para concentrarse',
        'icon': Icons.music_note,
        'color': Colors.pink,
        'onTap': () => _showComingSoon(context, "Música"),
      },
      {
        'title': 'Audiolibros',
        'subtitle': 'Lecciones narradas',
        'icon': Icons.headphones,
        'color': Colors.blue,
        'onTap': () => _showComingSoon(context, "Audiolibros"),
      },
      {
        'title': 'Podcast',
        'subtitle': 'Charlas y entrevistas',
        'icon': Icons.mic,
        'color': Colors.indigo,
        'onTap': () => _showComingSoon(context, "Podcasts"),
      },
      {
        'title': 'Cursos',
        'subtitle': 'Rutas de aprendizaje',
        'icon': Icons.school,
        'color': Colors.teal,
        'onTap': () => _showComingSoon(context, "Cursos"),
      },
      {
        'title': 'Libros',
        'subtitle': 'Material de lectura PDF',
        'icon': Icons.menu_book,
        'color': Colors.green,
        'onTap': () => _showComingSoon(context, "Libros"),
      },
      {
        'title': 'Documentos',
        'subtitle': 'Ensayos y apuntes',
        'icon': Icons.description,
        'color': Colors.orange,
        'onTap': () => _showComingSoon(context, "Documentos"),
      },
    ];

    return Scaffold(
      backgroundColor: isDark ? Colors.black : colors.surface,
      appBar: AppBar(
        title: const Text("Guardados", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: RepaintBoundary(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          // FÍSICA ESTÁNDAR DE ANDROID (Sin rebote iOS)
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            final folder = folders[index];
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildFolderCard(
                context,
                title: folder['title'],
                subtitle: folder['subtitle'],
                icon: folder['icon'],
                color: folder['color'],
                onTap: folder['onTap'],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Tu carpeta de $category estará disponible pronto"),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildFolderCard(
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
              // ICONO CON FONDO CIRCULAR (ESTILO NEXO)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              // TEXTOS ALINEADOS
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
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              // INDICADOR DE ACCESO
              Icon(
                Icons.folder_open_rounded,
                color: isDark ? Colors.white24 : Colors.black12,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}