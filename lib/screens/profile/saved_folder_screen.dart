import 'package:flutter/material.dart';
import 'saved_shorts_screen.dart';

class SavedFolderScreen extends StatelessWidget {
  const SavedFolderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Guardados", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Tus carpetas",
            style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          
          // Carpeta de Shorts
          _buildFolderItem(
            context,
            icon: Icons.video_library_rounded,
            title: "Shorts",
            subtitle: "Videos cortos educativos",
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedShortsScreen()),
              );
            },
          ),
          
          const SizedBox(height: 15),
          
          // Carpeta de Audios (Placeholder para el futuro)
          _buildFolderItem(
            context,
            icon: Icons.headphones_rounded,
            title: "Audios y Podcasts",
            subtitle: "Lecciones para escuchar",
            color: Colors.orange,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Próximamente: Carpeta de Audios")),
              );
            },
          ),

          const SizedBox(height: 15),

          // Carpeta de Documentos (Placeholder para el futuro)
          _buildFolderItem(
            context,
            icon: Icons.description_rounded,
            title: "Libros y Ensayos",
            subtitle: "Material de lectura guardado",
            color: Colors.green,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Próximamente: Carpeta de Documentos")),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFolderItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: colors.outlineVariant.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}