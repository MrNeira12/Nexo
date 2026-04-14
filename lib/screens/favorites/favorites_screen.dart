import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/content_item.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Favoritos", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Buscamos en la sub-colección 'favorites' dentro del usuario en Nexo
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('favorites')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // CASO 1: NO HAY NADA (Aislado con RepaintBoundary para rendimiento)
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return RepaintBoundary(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 80, color: colors.primary.withOpacity(0.2)),
                    const SizedBox(height: 20),
                    const Text(
                      "Aún no tienes favoritos",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Explora Nexo y guarda lo que más te guste.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          // Convertimos los datos de Firebase a nuestra lista de objetos de forma eficiente
          final List<ContentItem> allFavorites = snapshot.data!.docs.map((doc) {
            return ContentItem.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

          // CASO 2: HAY CONTENIDO (Organizado por categorías académicas con scroll nativo)
          return ListView(
            // OPTIMIZACIÓN 120HZ: Física de rebote nativa global de Nexo
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            children: [
              _buildCategorySection("Audiolibros", allFavorites.where((i) => i.type == 'audiolibro').toList(), Colors.blue),
              _buildCategorySection("Videos Educativos", allFavorites.where((i) => i.type == 'video').toList(), Colors.red),
              _buildCategorySection("Libros y PDF", allFavorites.where((i) => i.type == 'libro').toList(), Colors.green),
              _buildCategorySection("Ensayos", allFavorites.where((i) => i.type == 'ensayo').toList(), Colors.orange),
              _buildCategorySection("Música de Estudio", allFavorites.where((i) => i.type == 'musica').toList(), Colors.purple),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(String title, List<ContentItem> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 4, 
                  height: 22, 
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title, 
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)
                ),
                const Spacer(),
                Text(
                  "${items.length} elementos", 
                  style: const TextStyle(color: Colors.grey, fontSize: 13)
                ),
              ],
            ),
          ),
          
          // Lista horizontal de favoritos con optimización de desplazamiento
          SizedBox(
            height: 145,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              // OPTIMIZACIÓN 120HZ: Física de rebote nativa para listas horizontales
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  width: 125,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: color.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, color: color, size: 32),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }
}