import 'package:flutter/material.dart';

// Añadimos 'type' para clasificar el contenido
class ContentItem {
  final String id;
  final String title;
  final String author;
  final String category; // Ej: Ciencia, Historia
  final String type;     // Ej: audiolibro, video, libro, ensayo, musica
  final Color color;
  final IconData icon;

  ContentItem({
    required this.id,
    required this.title,
    required this.author, 
    required this.category, 
    required this.type,
    required this.color,
    this.icon = Icons.headphones,
  });

  // Función para convertir los datos de Firebase a este molde
  factory ContentItem.fromFirestore(Map<String, dynamic> data, String id) {
    return ContentItem(
      id: id,
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      category: data['category'] ?? '',
      type: data['type'] ?? 'audiolibro',
      color: Colors.blue, // Podrías guardar el color en Firebase también
      icon: _getIconByType(data['type']),
    );
  }

  static IconData _getIconByType(String? type) {
    switch (type) {
      case 'video': return Icons.play_circle;
      case 'libro': return Icons.menu_book;
      case 'ensayo': return Icons.article;
      case 'musica': return Icons.music_note;
      default: return Icons.headphones;
    }
  }
}