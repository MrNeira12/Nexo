import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

class NexoAudioService {
  // Singleton: Una sola instancia para toda la app
  static final NexoAudioService _instance = NexoAudioService._internal();
  factory NexoAudioService() => _instance;

  NexoAudioService._internal() {
    // Sincronización continua de posición y duración
    _audioPlayer.onPositionChanged.listen((p) => lastPosition = p);
    _audioPlayer.onDurationChanged.listen((d) => lastDuration = d);
    
    // Lógica de reproducción automática al terminar una canción
    _audioPlayer.onPlayerComplete.listen((event) {
      if (isRepeat) {
        // Si repetir está activo, reiniciamos la misma canción
        if (currentUrl != null) resumeFromZero();
      } else {
        // Si no, pasamos a la siguiente automáticamente
        playNext();
      }
    });
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Lista de reproducción actual y posición en la lista
  List<Map<String, dynamic>> playlist = [];
  int currentIndex = -1;

  // Estados de control de reproducción
  bool isShuffle = false;
  bool isRepeat = false;

  // Metadatos de la canción actual
  String currentTitle = "";
  String currentAuthor = "";
  String currentImg = "";
  String? currentUrl;
  bool isYouTube = false;

  // Variables de persistencia
  Duration lastPosition = Duration.zero;
  Duration lastDuration = Duration.zero;

  AudioPlayer get player => _audioPlayer;

  // Configura la lista de canciones desde la nube (se llama desde MusicScreen)
  void setPlaylist(List<Map<String, dynamic>> list, int startIndex) {
    playlist = list;
    currentIndex = startIndex;
  }

  // Carga e inicia un nuevo audio
  Future<void> playNew(String url, String title, String author, String img, {bool youtube = false}) async {
    currentUrl = url;
    currentTitle = title;
    currentAuthor = author;
    currentImg = img;
    isYouTube = youtube;
    
    lastPosition = Duration.zero;
    lastDuration = Duration.zero;

    if (!isYouTube) {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    }
  }

  // Lógica para saltar a la siguiente canción
  Future<void> playNext() async {
    if (playlist.isEmpty) return;

    if (isShuffle) {
      // Elegimos una canción al azar si el modo aleatorio está activo
      currentIndex = Random().nextInt(playlist.length);
    } else {
      // Avanzamos de forma lineal
      currentIndex = (currentIndex + 1) % playlist.length;
    }

    final nextSong = playlist[currentIndex];
    await playNew(
      nextSong['url'] ?? '',
      nextSong['title'] ?? 'Sin título',
      nextSong['author'] ?? 'Desconocido',
      nextSong['coverUrl'] ?? '',
      youtube: nextSong['isYouTube'] ?? false,
    );
  }

  // Lógica para volver a la canción anterior
  Future<void> playPrevious() async {
    if (playlist.isEmpty) return;

    if (lastPosition.inSeconds > 3) {
      // Si el usuario ya lleva más de 3 segundos escuchando, reinicia la canción
      await resumeFromZero();
    } else {
      // Si no, retrocede a la canción anterior
      currentIndex = (currentIndex - 1 < 0) ? playlist.length - 1 : currentIndex - 1;
      final prevSong = playlist[currentIndex];
      await playNew(
        prevSong['url'] ?? '',
        prevSong['title'] ?? 'Sin título',
        prevSong['author'] ?? 'Desconocido',
        prevSong['coverUrl'] ?? '',
        youtube: prevSong['isYouTube'] ?? false,
      );
    }
  }

  Future<void> resumeFromZero() async {
    await _audioPlayer.seek(Duration.zero);
    await _audioPlayer.resume();
  }

  void toggleShuffle() => isShuffle = !isShuffle;
  void toggleRepeat() => isRepeat = !isRepeat;

  Future<void> pause() async => await _audioPlayer.pause();
  Future<void> resume() async => await _audioPlayer.resume();
}