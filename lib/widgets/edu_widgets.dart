import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/content_item.dart';
import '../services/audio_service.dart';
import 'audio_player_detail.dart';

// El reproductor pequeño sincronizado con el motor global de Nexo
// Optimizado para 120Hz eliminando reconstrucciones innecesarias
class MiniPlayerBlur extends StatefulWidget {
  const MiniPlayerBlur({super.key});

  @override
  State<MiniPlayerBlur> createState() => _MiniPlayerBlurState();
}

class _MiniPlayerBlurState extends State<MiniPlayerBlur> with SingleTickerProviderStateMixin {
  final audioService = NexoAudioService();
  bool isPlaying = false;
  bool _isDismissed = false;

  late AnimationController _bounceController;
  late Animation<Offset> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _bounceAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(0.05, 0.0)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.05, 0.0), end: const Offset(-0.05, 0.0)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.05, 0.0), end: Offset.zero), weight: 25),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut));

    _setupStateListeners();
  }

  void _setupStateListeners() {
    // Solo escuchamos el estado de reproducción para actualizar iconos
    // El progreso se maneja de forma aislada para optimizar 120Hz
    if (mounted) {
      setState(() {
        isPlaying = audioService.player.state == PlayerState.playing;
      });
    }

    audioService.player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          isPlaying = state == PlayerState.playing;
          if (isPlaying) _isDismissed = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    if (audioService.currentUrl == null || _isDismissed) {
      return const SizedBox.shrink();
    }

    // AISLAMIENTO DE GPU: Evita redibujar el resto de la app cuando el miniplayer se anima
    return RepaintBoundary(
      child: SlideTransition(
        position: _bounceAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          height: 72,
          child: Dismissible(
            key: Key(audioService.currentUrl!), 
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              if (isPlaying) {
                _bounceController.forward(from: 0);
                return false;
              }
              return true;
            },
            onDismissed: (direction) {
              setState(() => _isDismissed = true);
            },
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => AudioPlayerDetail(
                      title: audioService.currentTitle,
                      author: audioService.currentAuthor,
                      imageUrl: audioService.currentImg,
                      videoUrl: audioService.currentUrl,
                      isYouTube: audioService.isYouTube,
                    ),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.35), 
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1), 
                        width: 1.0
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                Hero(
                                  tag: 'player_art',
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      image: DecorationImage(
                                        image: NetworkImage(audioService.currentImg.isNotEmpty 
                                          ? audioService.currentImg 
                                          : 'https://images.unsplash.com/photo-1507838153414-b4b713384a76?q=80&w=1000&auto=format&fit=crop'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        audioService.currentTitle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        audioService.currentAuthor,
                                        style: TextStyle(
                                          fontSize: 10, 
                                          color: Colors.white.withOpacity(0.6),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Controles simplificados para mayor fluidez
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 26),
                                      onPressed: () => audioService.playPrevious(),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      icon: Icon(
                                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                                        size: 32, 
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        isPlaying ? audioService.pause() : audioService.resume();
                                      },
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 26),
                                      onPressed: () => audioService.playNext(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Barra de progreso aislada en su propio widget para evitar lag
                        const _ProgressBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget optimizado para manejar el progreso sin reconstruir todo el MiniPlayer
class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    final audioService = NexoAudioService();

    return RepaintBoundary(
      child: SizedBox(
        height: 2.0,
        child: StreamBuilder<Duration>(
          stream: audioService.player.onPositionChanged,
          builder: (context, snapshot) {
            final position = snapshot.data ?? audioService.lastPosition;
            final duration = audioService.lastDuration;
            
            return LinearProgressIndicator(
              value: (duration.inMilliseconds > 0) 
                  ? (position.inMilliseconds / duration.inMilliseconds) 
                  : 0.0,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            );
          },
        ),
      ),
    );
  }
}

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
              overflow: TextOverflow.ellipsis
            ),
            Text(
              content.author, 
              style: const TextStyle(color: Colors.grey, fontSize: 12)
            ),
          ],
        ),
      ),
    );
  }
}