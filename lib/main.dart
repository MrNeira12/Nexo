import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importación de configuración y piezas modulares
import 'firebase_options.dart';
import 'widgets/edu_widgets.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/interests_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/shorts/shorts_screen.dart';
// Nueva importación para la pantalla de explorar
import 'screens/explore/explore_screen.dart';

void main() async {
  // Garantiza que Flutter esté listo antes de iniciar Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización de Firebase con las opciones generadas
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const EduSpotifyApp());
}

class EduSpotifyApp extends StatelessWidget {
  const EduSpotifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduSpotify',
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
        // Estado de carga inicial de Firebase Auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        // Si el usuario tiene una sesión activa
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
              
              // Verificación de intereses para personalizar el inicio
              if (userData == null || 
                  userData['interests'] == null || 
                  (userData['interests'] as List).isEmpty) {
                return const InterestsScreen();
              }
              
              return const MainNavigation();
            },
          );
        }
        
        // Si no hay sesión, mostramos la alternancia entre Login y Registro
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    // Generamos las pantallas pasando el estado de actividad para pausar videos
    final List<Widget> screens = [
      const ExploreScreen(), // <--- Cambiado de Center a ExploreScreen
      EduShortsScreen(isActive: _selectedIndex == 1),                             
      const ProfileScreen(),                               
    ];

    return Scaffold(
      // La barra de navegación se mantiene en su ranura estándar
      bottomNavigationBar: NavigationBar(
        elevation: 0,
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
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
            label: 'EduShorts'
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline), 
            selectedIcon: Icon(Icons.person),
            label: 'Perfil'
          ),
        ],
      ),
      // Usamos un Stack en el body para permitir que el MiniPlayer flote
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
          
          // El MiniPlayer solo aparece si NO estamos en EduShorts (index 1)
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