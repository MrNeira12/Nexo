import 'package:flutter/material.dart';

/// Modelo de datos optimizado para alto rendimiento (120Hz).
/// La inmutabilidad garantiza que Flutter pueda cachear instancias de forma eficiente.
@immutable
class ContentItem {
  final String id;
  final String title;
  final String author;
  final String category; // Ej: Ciencia, Historia
  final String type;     // Ej: audiolibro, video, libro, ensayo, musica
  final Color color;
  final IconData icon;

  // Constructor const: Crucial para optimizar el árbol de widgets
  const ContentItem({
    required this.id,
    required this.title,
    required this.author, 
    required this.category, 
    required this.type,
    required this.color,
    this.icon = Icons.headphones,
  });

  /// Crea una copia del item con algunos campos modificados.
  /// Útil para actualizaciones de estado rápidas sin mutar el objeto original.
  ContentItem copyWith({
    String? id,
    String? title,
    String? author,
    String? category,
    String? type,
    Color? color,
    IconData? icon,
  }) {
    return ContentItem(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      category: category ?? this.category,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }

  /// Función para convertir los datos de Firebase al modelo de Nexo.
  factory ContentItem.fromFirestore(Map<String, dynamic> data, String id) {
    return ContentItem(
      id: id,
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      category: data['category'] ?? '',
      type: data['type'] ?? 'audiolibro',
      color: Colors.blue, // Se puede expandir para leer colores desde DB
      icon: _getIconByType(data['type']),
    );
  }

  /// Helper estático optimizado para asignar iconos por tipo de contenido.
  static IconData _getIconByType(String? type) {
    switch (type) {
      case 'video': return Icons.play_circle;
      case 'libro': return Icons.menu_book;
      case 'ensayo': return Icons.article;
      case 'musica': return Icons.music_note;
      default: return Icons.headphones;
    }
  }

  // --- OPTIMIZACIÓN DE COMPARACIÓN ---
  // Estos métodos permiten que Flutter sepa si el contenido es idéntico 
  // y evitar re-dibujar la tarjeta en pantallas de 120Hz.

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          author == other.author &&
          category == other.category &&
          type == other.type &&
          color == other.color;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      author.hashCode ^
      category.hashCode ^
      type.hashCode ^
      color.hashCode;
}