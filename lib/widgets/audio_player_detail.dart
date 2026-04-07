import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:audioplayers/audioplayers.dart' as ap; // Motor para reproducir MP3

class AudioPlayerDetail extends StatefulWidget {
  final String title;
  final String author;
  final String imageUrl;
  final String? videoUrl; // URL que viene de Firebase (MP3 o YouTube)
  final bool isYouTube;   // Booleano para saber qué reproductor activar

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
  // Controladores de los motores de reproducción
  late YoutubePlayerController _ytController;
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  
  bool _isPlayerReady = false;
  bool isPlaying = true;
  
  // Variables para controlar el tiempo del audio MP3
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _iniciarReproduccion();
  }

  void _iniciarReproduccion() {
    if (widget.isYouTube && widget.videoUrl != null) {
      // CONFIGURACIÓN PARA YOUTUBE
      final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl!);
      _ytController = YoutubePlayerController(
        initialVideoId: videoId ?? '',
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: false,
        ),
      )..addListener(_ytListener);
    } else if (widget.videoUrl != null) {
      // CONFIGURACIÓN PARA AUDIO MP3 (Firebase Storage)
      _configurarAudio();
    }
  }

  Future<void> _configurarAudio() async {
    // Escuchar la duración total del archivo
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    // Escuchar la posición actual (progreso)
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });

    // Escuchar cambios de estado (si el usuario pulsa play/pausa)
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => isPlaying = state == ap.PlayerState.playing);
      }
    });

    // Reproducir automáticamente al entrar
    try {
      await _audioPlayer.play(ap.UrlSource(widget.videoUrl!));
    } catch (e) {
      debugPrint("Error al reproducir audio: $e");
    }
  }

  void _ytListener() {
    if (_isPlayerReady && mounted && !_ytController.value.isFullScreen) {
      setState(() {
        isPlaying = _ytController.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    // Liberar memoria al cerrar la pantalla
    if (widget.isYouTube) _ytController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Formatear segundos a 00:00
  String _formatearTiempo(Duration duration) {
    String dosDigitos(int n) => n.toString().padLeft(2, "0");
    String minutos = dosDigitos(duration.inMinutes.remainder(60));
    String segundos = dosDigitos(duration.inSeconds.remainder(60));
    return "$minutos:$segundos";
  }

  @override
  Widget build(BuildContext context) {
    // Evitar el error de URI file:/// con una imagen de respaldo
    final validImageUrl = (widget.imageUrl.isEmpty || !widget.imageUrl.startsWith('http'))
        ? 'https://images.unsplash.com/photo-1507838153414-b4b713384a76?q=80&w=1000&auto=format&fit=crop'
        : widget.imageUrl;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo con blur dinámico
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(validImageUrl),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Cabecera
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 35),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        widget.isYouTube ? "VIDEO EDUCATIVO" : "REPRODUCIENDO AUDIO",
                        style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 45),
                    ],
                  ),
                ),
                
                const Spacer(),

                // VISUALIZADOR (Video o Imagen)
                Hero(
                  tag: 'player_art',
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: widget.isYouTube
                          ? YoutubePlayer(
                              controller: _ytController,
                              showVideoProgressIndicator: true,
                              onReady: () => _isPlayerReady = true,
                            )
                          : Image.network(
                              validImageUrl,
                              height: MediaQuery.of(context).size.width * 0.9,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),

                const Spacer(),

                // Información
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.author,
                        style: const TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // BARRA DE PROGRESO (Sincronizada con el audio)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Slider(
                        value: widget.isYouTube ? 0.0 : _position.inSeconds.toDouble(),
                        max: widget.isYouTube ? 1.0 : _duration.inSeconds.toDouble().clamp(1.0, double.infinity),
                        activeColor: Colors.white,
                        inactiveColor: Colors.white24,
                        onChanged: widget.isYouTube ? null : (v) async {
                          await _audioPlayer.seek(Duration(seconds: v.toInt()));
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(widget.isYouTube ? "En vivo" : _formatearTiempo(_position), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            Text(widget.isYouTube ? "" : _formatearTiempo(_duration), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // CONTROLES PRINCIPALES
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Icon(Icons.shuffle, color: Colors.white60),
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Colors.white, size: 40),
                        onPressed: () => _audioPlayer.seek(Duration.zero),
                      ),
                      GestureDetector(
                        onTap: () async {
                          if (widget.isYouTube) {
                            _ytController.value.isPlaying ? _ytController.pause() : _ytController.play();
                          } else {
                            isPlaying ? await _audioPlayer.pause() : await _audioPlayer.resume();
                          }
                        },
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 40),
                        ),
                      ),
                      const Icon(Icons.skip_next, color: Colors.white, size: 40),
                      const Icon(Icons.repeat, color: Colors.white60),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}