import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart'; // Soporte para alta frecuencia
import 'dart:ui'; // Necesario para ImageFilter

// Importación de configuración y piezas modulares
import 'firebase_options.dart';
import 'widgets/edu_widgets.dart';
import 'services/audio_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/interests_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/shorts/shorts_screen.dart';
import 'screens/explore/explore_screen.dart';
import 'screens/upload/upload_selection_screen.dart'; 

void main() async {
  // 1. Garantizar que Flutter y sus canales nativos estén listos
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicialización Protegida de Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    
    debugPrint("✅ Firebase inicializado con éxito en la capa de Flutter");
    
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        debugPrint("👤 Sesión activa detectada: ${user.uid}");
      }
    });
    
  } catch (e) {
    debugPrint("⚠️ Advertencia de Inicio: Firebase no pudo conectar de inmediato. Error: $e");
  }

  // 3. OPTIMIZACIÓN DE RENDIMIENTO: Forzar Hz nativos (120Hz/144Hz)
  await setOptimalDisplayMode();
  
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  runApp(const NexoApp());
}

Future<void> setOptimalDisplayMode() async {
  try {
    final List<DisplayMode> modes = await FlutterDisplayMode.supported;
    if (modes.isEmpty) return;

    DisplayMode optimalMode = modes.reduce((a, b) {
      if (a.refreshRate > b.refreshRate) return a;
      if (a.refreshRate == b.refreshRate && a.width > b.width) return a;
      return b;
    });

    await FlutterDisplayMode.setPreferredMode(optimalMode);
  } catch (e) {
    debugPrint("Info: No se pudo forzar Hz manualmente: $e");
  }
}

class NexoApp extends StatelessWidget {
  const NexoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        navigationBarTheme: NavigationBarThemeData(
          // MEJORA: Eliminadas sombras, mantenido peso visual para legibilidad
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            bool isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.blue : Colors.black87,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            // Restaurado a la línea de estilo original
            return IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected) ? Colors.blue : Colors.black54,
            );
          }),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
          surface: Colors.black,
        ),
        navigationBarTheme: NavigationBarThemeData(
          // MEJORA: Limpieza visual en modo oscuro
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            bool isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.white70,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected) ? Colors.white : Colors.white54,
            );
          }),
        ),
        appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.black),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}

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
              
              if (userSnap.hasError) {
                debugPrint("❌ Error en Firestore: ${userSnap.error}");
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

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _showLogin = true;
  void _toggleView() => setState(() => _showLogin = !_showLogin);

  @override
  Widget build(BuildContext context) {
    return _showLogin 
        ? LoginScreen(onToggle: _toggleView) 
        : RegisterScreen(onToggle: _toggleView);
  }
}

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    
    final List<Widget> screens = [
      const ExploreScreen(),
      NexoShortsScreen(isActive: _selectedIndex == 1),
      const UploadSelectionScreen(),
      const ProfileScreen(),                               
    ];

    return Scaffold(
      backgroundColor: isDark ? Colors.black : colors.surface,
      extendBody: true,
      bottomNavigationBar: RepaintBoundary(
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 70, 
              decoration: BoxDecoration(
                // AJUSTE: Se eliminó el degradado y se volvió a un color plano con opacidad baja
                color: (isDark ? Colors.black : Colors.white).withOpacity(0.08),
                border: Border(
                  top: BorderSide(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: NavigationBar(
                elevation: 0,
                height: 60,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: Colors.transparent, 
                selectedIndex: _selectedIndex,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (index) {
                  if (index == 1) audioService.pause();
                  setState(() => _selectedIndex = index);
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
                    label: 'Shorts'
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.add_box_outlined), 
                    selectedIcon: Icon(Icons.add_box), 
                    label: 'Publicar'
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline), 
                    selectedIcon: Icon(Icons.person), 
                    label: 'Perfil'
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          RepaintBoundary(
            child: IndexedStack(index: _selectedIndex, children: screens),
          ),
          if (_selectedIndex == 0 || _selectedIndex == 3)
            const Positioned(bottom: 85, left: 10, right: 10, child: MiniPlayerBlur()),
        ],
      ),
    );
  }
}