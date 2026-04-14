import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import '../services/audio_service.dart';

class AudioPlayerDetail extends StatefulWidget {
  final String title;
  final String author;
  final String imageUrl;
  final String? videoUrl;
  final bool isYouTube;

  const AudioPlayerDetail({
    super.key,
    required this.title,
    required this.author,
    required this.imageUrl,
    this.videoUrl,
    this.isYouTube = false,
  });

  @override
  State<AudioPlayerDetail> createState() => _AudioPlayerDetailState();
}

class _AudioPlayerDetailState extends State<AudioPlayerDetail> {
  final audioService = NexoAudioService();
  
  YoutubePlayerController? _ytController;
  bool _isPlayerReady = false;
  bool isPlaying = false;
  bool _isDragging = false;
  
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Variable de control para detectar cambios de canción por gestos
  String? _lastProcessedUrl;

  @override
  void initState() {
    super.initState();
    _lastProcessedUrl = audioService.currentUrl;
    _inicializarYoutubeSiAplica();
    _sincronizarConServicioGlobal();
  }

  void _inicializarYoutubeSiAplica() {
    final bool currentlyIsYouTube = audioService.isYouTube;
    final String? currentUrl = audioService.currentUrl;

    if (currentlyIsYouTube && currentUrl != null) {
      final videoId = YoutubePlayer.convertUrlToId(currentUrl);
      _ytController = YoutubePlayerController(
        initialVideoId: videoId ?? '',
        flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
      )..addListener(_ytListener);
    }
  }

  // Función crítica para solucionar el bug de "video trabado"
  void _limpiarYReactivarYoutube() {
    if (mounted) {
      setState(() {
        _isPlayerReady = false;
        _ytController?.dispose();
        _ytController = null;
        _duration = Duration.zero;
        _position = Duration.zero;
      });
      _inicializarYoutubeSiAplica();
    }
  }

  Future<void> _sincronizarConServicioGlobal() async {
    if (mounted) {
      setState(() {
        isPlaying = audioService.player.state == ap.PlayerState.playing;
        _position = audioService.lastPosition;
        _duration = audioService.lastDuration;
      });
    }

    // Escuchar cambios de duración
    audioService.player.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    // Escuchar cambios de posición y detectar cambio de canción
    audioService.player.onPositionChanged.listen((newPosition) {
      if (mounted) {
        // DETECCIÓN DE BUG: Si la URL del servicio cambió, reiniciamos el reproductor
        if (audioService.currentUrl != _lastProcessedUrl) {
          _lastProcessedUrl = audioService.currentUrl;
          _limpiarYReactivarYoutube();
          return;
        }

        if (_duration == Duration.zero) {
          audioService.player.getDuration().then((d) {
            if (d != null) setState(() => _duration = d);
          });
        }
        if (!_isDragging) {
          setState(() => _position = newPosition);
        }
      }
    });

    // Escuchar cambios de estado (Play/Pause)
    audioService.player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => isPlaying = state == ap.PlayerState.playing);
      }
    });
  }

  void _ytListener() {
    if (_isPlayerReady && mounted && _ytController != null && !_ytController!.value.isFullScreen) {
      setState(() {
        isPlaying = _ytController!.value.isPlaying;
        // Sincronizar duración del video si es YouTube
        if (_ytController!.value.isReady) {
          _duration = _ytController!.metadata.duration;
          _position = _ytController!.value.position;
        }
      });
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  String _formatearTiempo(Duration duration) {
    String dosDigitos(int n) => n.toString().padLeft(2, "0");
    String minutos = dosDigitos(duration.inMinutes.remainder(60));
    String segundos = dosDigitos(duration.inSeconds.remainder(60));
    return "$minutos:$segundos";
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    // Obtenemos los metadatos SIEMPRE del servicio para que el swiping funcione
    final String currentTitle = audioService.currentTitle.isNotEmpty ? audioService.currentTitle : widget.title;
    final String currentAuthor = audioService.currentAuthor.isNotEmpty ? audioService.currentAuthor : widget.author;
    final String currentImg = audioService.currentImg.isNotEmpty ? audioService.currentImg : widget.imageUrl;

    final validImageUrl = (currentImg.isEmpty || !currentImg.startsWith('http'))
        ? 'https://images.unsplash.com/photo-1507838153414-b4b713384a76?q=80&w=1000&auto=format&fit=crop'
        : currentImg;

    return PopScope(
      canPop: true,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 600) {
            Navigator.pop(context);
          }
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < -500) {
            audioService.playNext();
          } else if (details.primaryVelocity! > 500) {
            audioService.playPrevious();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // FONDO DINÁMICO
              RepaintBoundary(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(validImageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.7),
                            Colors.black,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 35),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Text(
                            audioService.isYouTube ? "VIDEO" : "NEXO AUDIO",
                            style: const TextStyle(
                              color: Colors.white70, 
                              fontSize: 10, 
                              letterSpacing: 2, 
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 45),
                        ],
                      ),
                    ),
                    
                    const Spacer(),

                    // CARÁTULA O VIDEO
                    Hero(
                      tag: 'player_art',
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.82,
                        height: MediaQuery.of(context).size.width * 0.82,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5), 
                              blurRadius: 40, 
                              spreadRadius: 5
                            )
                          ],
                          image: DecorationImage(
                            image: NetworkImage(validImageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: audioService.isYouTube && _ytController != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: YoutubePlayer(
                                key: ValueKey(audioService.currentUrl), // Forzar reconstrucción al cambiar URL
                                controller: _ytController!,
                                showVideoProgressIndicator: true,
                                onReady: () => _isPlayerReady = true,
                              ),
                            )
                          : null,
                      ),
                    ),

                    const Spacer(),

                    // INFORMACIÓN
                    SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 35),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentTitle,
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 28, 
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.left,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              currentAuthor,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6), 
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // BARRA DE PROGRESO
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: RepaintBoundary(
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white10,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: _position.inMilliseconds.toDouble().clamp(
                                  0.0, 
                                  _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 0.0
                                ),
                                max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                                onChangeStart: (v) => setState(() => _isDragging = true),
                                onChanged: (v) => setState(() => _position = Duration(milliseconds: v.toInt())),
                                onChangeEnd: (v) async {
                                  if (audioService.isYouTube && _ytController != null) {
                                    _ytController!.seekTo(Duration(milliseconds: v.toInt()));
                                  } else {
                                    await audioService.player.seek(Duration(milliseconds: v.toInt()));
                                  }
                                  setState(() => _isDragging = false);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatearTiempo(_position), style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text(_formatearTiempo(_duration), style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // CONTROLES
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSmallAction(
                            Icons.shuffle_rounded, 
                            audioService.isShuffle ? colors.primary : Colors.white38,
                            () => setState(() => audioService.toggleShuffle())
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 48),
                            onPressed: () => audioService.playPrevious(),
                          ),
                          _buildMainPlayButton(colors),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 48),
                            onPressed: () => audioService.playNext(),
                          ),
                          _buildSmallAction(
                            Icons.repeat_one_rounded, 
                            audioService.isRepeat ? colors.primary : Colors.white38,
                            () => setState(() => audioService.toggleRepeat())
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildMainPlayButton(ColorScheme colors) {
    return GestureDetector(
      onTap: () async {
        if (audioService.isYouTube && _ytController != null) {
          _ytController!.value.isPlaying ? _ytController!.pause() : _ytController!.play();
        } else {
          isPlaying ? await audioService.pause() : await audioService.resume();
        }
      },
      child: Container(
        height: 80,
        width: 80,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
          color: Colors.black, 
          size: 45
        ),
      ),
    );
  }
}