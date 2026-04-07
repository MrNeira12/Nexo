import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/content_item.dart';
// Importamos el detalle para la navegación
import 'audio_player_detail.dart';

// El reproductor pequeño que flota en la parte inferior
class MiniPlayerBlur extends StatefulWidget {
  const MiniPlayerBlur({super.key});

  @override
  State<MiniPlayerBlur> createState() => _MiniPlayerBlurState();
}

class _MiniPlayerBlurState extends State<MiniPlayerBlur> {
  bool isPlaying = true;
  double progressValue = 0.35; // Simulación de progreso actual

  // Datos de ejemplo para el reproductor actual
  final String currentTitle = "Física Cuántica - Cap 1";
  final String currentAuthor = "Dr. Alberto Einstein";
  final String currentImg = "https://images.unsplash.com/photo-1635070041078-e363dbe005cb?q=80&w=1000&auto=format&fit=crop";

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navegación animada hacia la pantalla de detalle
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AudioPlayerDetail(
              title: currentTitle,
              author: currentAuthor,
              imageUrl: currentImg,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0); // Desliza desde abajo hacia arriba
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;
              var slideTransition = animation.drive(
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve)),
              );
              return SlideTransition(position: slideTransition, child: child);
            },
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 72, // Altura ajustada para controles y barra
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        // Portada en miniatura (Izquierda) con Hero para transición fluida
                        Hero(
                          tag: 'player_art',
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: NetworkImage(currentImg),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Información del título y autor (Centro)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 14
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                currentAuthor,
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8)
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        // Controles de audio (Derecha)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.skip_previous, size: 24),
                              onPressed: () {
                                // Lógica de reinicio o anterior
                              },
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, 
                                size: 38, 
                                color: Theme.of(context).colorScheme.primary
                              ),
                              onPressed: () {
                                setState(() => isPlaying = !isPlaying);
                              },
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.skip_next, size: 24),
                              onPressed: () {
                                // Lógica de siguiente
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Barra de progreso inferior fina
                SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// La tarjeta cuadrada que muestra cada audiolibro
class ContentCard extends StatelessWidget {
  final ContentItem content;
  final VoidCallback onTap;

  const ContentCard({super.key, required this.content, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                color: content.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(content.icon, size: 60, color: content.color),
            ),
            const SizedBox(height: 8),
            Text(
              content.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              content.author,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}