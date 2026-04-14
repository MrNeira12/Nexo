import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importación de configuración y piezas modulares
// RUTAS CORREGIDAS PARA LA UBICACIÓN: lib/screens/music/music_screen.dart
import '../../firebase_options.dart';
import '../../widgets/edu_widgets.dart';
import '../../services/audio_service.dart'; // Importación vital para el control global
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/interests_screen.dart';
import '../profile/profile_screen.dart';
import '../shorts/shorts_screen.dart';
import '../explore/explore_screen.dart';
import '../../widgets/audio_player_detail.dart';
import 'upload_music_screen.dart';

void main() async {
  // Garantiza que Flutter esté listo antes de iniciar Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización de Firebase con las opciones generadas
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const NexoApp());
}

class NexoApp extends StatelessWidget {
  const NexoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexo',
      debugShowCheckedModeBanner: false,
      // Configuración de temas (Claro y Oscuro)
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      // El AuthWrapper gestiona el flujo de autenticación
      home: const AuthWrapper(),
    );
  }
}

// --- LÓGICA DE FLUJO DE USUARIO ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .snapshots(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              final userData = userSnap.data?.data() as Map<String, dynamic>?;
              
              if (userData == null || 
                  userData['interests'] == null || 
                  (userData['interests'] as List).isEmpty) {
                return const InterestsScreen();
              }
              
              return const MainNavigation();
            },
          );
        }
        
        return const AuthPage();
      },
    );
  }
}

// --- ALTERNANCIA LOGIN / REGISTRO ---
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _showLogin = true;

  void _toggleView() {
    setState(() {
      _showLogin = !_showLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      return LoginScreen(onToggle: _toggleView);
    } else {
      return RegisterScreen(onToggle: _toggleView);
    }
  }
}

// --- NAVEGACIÓN PRINCIPAL ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final audioService = NexoAudioService();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    final List<Widget> _screens = [
      const ExploreScreen(),
      NexoShortsScreen(isActive: _selectedIndex == 1),                                
      const ProfileScreen(),                                
    ];

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        elevation: 0,
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          // LÓGICA DINÁMICA: Solo pausamos si entramos a Shorts.
          if (index == 1) {
            audioService.pause();
          }

          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined), 
            selectedIcon: Icon(Icons.home),
            label: 'Explorar'
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline), 
            selectedIcon: Icon(Icons.play_circle),
            label: 'Nexo Shorts'
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline), 
            selectedIcon: Icon(Icons.person),
            label: 'Perfil'
          ),
        ],
      ),
      body: Stack(
        children: [
          // Usamos IndexedStack para mantener el estado de las páginas al navegar
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          
          // El MiniPlayer flota en todas las pestañas excepto en Shorts (índice 1)
          if (_selectedIndex != 1)
            const Positioned(
              bottom: 10, 
              left: 10, 
              right: 10, 
              child: MiniPlayerBlur(),
            ),
        ],
      ),
    );
  }
}

// --- CLASE AÑADIDA PARA SOLUCIONAR EL ERROR DE EXPLORESCREEN ---
// Esta clase permite que ExploreScreen la reconozca y navegue aquí
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final audioService = NexoAudioService();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Música Educativa", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('music')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_off_rounded, size: 80, color: colors.outlineVariant),
                      const SizedBox(height: 16),
                      const Text("No hay música disponible aún", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 130),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final String title = data['title'] ?? 'Sin título';
                  final String author = data['author'] ?? 'Autor desconocido';
                  final String coverUrl = data['coverUrl'] ?? '';
                  final String url = data['url'] ?? '';
                  final bool isYouTube = data['isYouTube'] ?? false;

                  final bool isCurrent = audioService.currentUrl == url;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: isCurrent ? 4 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(
                        color: isCurrent ? colors.primary : colors.outlineVariant.withOpacity(0.2),
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(10),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          coverUrl.isNotEmpty ? coverUrl : 'https://images.unsplash.com/photo-1507838153414-b4b713384a76?q=80&w=1000&auto=format&fit=crop',
                          width: 55,
                          height: 55,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(title, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(author),
                      trailing: Icon(
                        isCurrent ? Icons.equalizer : (isYouTube ? Icons.play_circle_outline : Icons.play_arrow_rounded), 
                        color: colors.primary
                      ),
                      onTap: () {
                        audioService.setPlaylist(docs.map((e) => e.data() as Map<String, dynamic>).toList(), index);
                        if (!isCurrent) {
                          audioService.playNew(url, title, author, coverUrl, youtube: isYouTube);
                        }
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AudioPlayerDetail(
                              title: title,
                              author: author,
                              imageUrl: coverUrl,
                              videoUrl: url,
                              isYouTube: isYouTube,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          
          const Positioned(
            bottom: 15,
            left: 10,
            right: 10,
            child: MiniPlayerBlur(),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100), 
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UploadMusicScreen()),
            );
          },
          label: const Text("Subir Música"),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }
}