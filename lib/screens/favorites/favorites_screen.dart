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
        title: const Text("Mis Favoritos"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Buscamos en la sub-colección 'favorites' dentro del usuario
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('favorites')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // CASO 1: NO HAY NADA (Mensaje amigable)
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: colors.primary.withOpacity(0.3)),
                  const SizedBox(height: 20),
                  const Text(
                    "Aún no tienes favoritos",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Explora la academia y guarda lo que más te guste.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Convertimos los datos de Firebase a nuestra lista de objetos
          List<ContentItem> allFavorites = snapshot.data!.docs.map((doc) {
            return ContentItem.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

          // CASO 2: HAY CONTENIDO (Organizado por categorías)
          return ListView(
            padding: const EdgeInsets.all(15),
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
    if (items.isEmpty) return const SizedBox.shrink(); // Si no hay de este tipo, no mostramos la sección

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(width: 4, height: 20, color: color),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text("${items.length} items", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        // Lista horizontal de favoritos de este tipo
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: color, size: 30),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
        const SizedBox(height: 20),
      ],
    );
  }
}