import 'package:flutter/material.dart';
// Importamos las pantallas necesarias para la navegación
import '../music/music_screen.dart';
import '../music/upload_music_screen.dart'; // Importación para el acceso directo a subir música

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _selectedCategory = "Todos";

  // Categorías de exploración con sus respectivos iconos
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Todos', 'icon': Icons.grid_view_rounded},
    {'name': 'Libros', 'icon': Icons.menu_book_rounded},
    {'name': 'Música', 'icon': Icons.music_note_rounded},
    {'name': 'Audiolibros', 'icon': Icons.headphones_rounded},
    {'name': 'Documentos', 'icon': Icons.description_rounded},
    {'name': 'Podcasts', 'icon': Icons.mic_external_on_rounded},
    {'name': 'Cursos', 'icon': Icons.school_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      // AÑADIMOS UN ACCESO RÁPIDO PARA SUBIR MÚSICA/CONTENIDO
      // Este botón aparecerá cuando estemos en "Todos" o hayamos vuelto de "Música"
      floatingActionButton: _selectedCategory == "Todos" || _selectedCategory == "Música"
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UploadMusicScreen()),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Subir Contenido", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: colors.primary,
            )
          : null,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // BARRA DE BÚSQUEDA Y TÍTULO
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Explorar",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      decoration: InputDecoration(
                        hintText: "Busca libros, música, audios...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: colors.surfaceContainerHighest.withOpacity(0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // SECCIÓN DE CATEGORÍAS (Horizontal)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat['name'];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = cat['name']);
                        
                        // Lógica de navegación: Si es Música, vamos a su pantalla de lista
                        if (cat['name'] == 'Música') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MusicScreen()),
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.primary : colors.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              cat['icon'],
                              size: 18,
                              color: isSelected ? Colors.white : colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cat['name'],
                              style: TextStyle(
                                color: isSelected ? Colors.white : colors.onSurfaceVariant,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // CONTENIDO DE TENDENCIAS
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildSectionHeader("Tendencias en ${_selectedCategory == 'Todos' ? 'la Academia' : _selectedCategory}"),
                    const SizedBox(height: 15),
                    
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        return Container(
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_stories, size: 40, color: colors.primary.withOpacity(0.5)),
                              const SizedBox(height: 10),
                              const Text("Contenido", style: TextStyle(fontWeight: FontWeight.bold)),
                              const Text("Próximamente", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 100)), 
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text("Ver todo", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
      ],
    );
  }
}