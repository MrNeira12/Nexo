import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onToggle;
  const LoginScreen({super.key, required this.onToggle});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLoading = false;

  // Función para mostrar alertas rápidas (SnackBars)
  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto), 
        backgroundColor: Colors.blueAccent, 
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _login() async {
    // Verificación básica de campos vacíos
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _mostrarMensaje("Por favor, llena todos los campos.");
      return;
    }

    setState(() => isLoading = true);

    try {
      // Intento de inicio de sesión con Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Al tener éxito, el AuthWrapper en main.dart detectará el cambio automáticamente
    } on FirebaseAuthException catch (e) {
      String mensajeError = "Ocurrió un error inesperado.";
      
      // Manejo específico de errores comunes de Firebase
      switch (e.code) {
        case 'user-not-found': 
          mensajeError = "Este correo no está registrado."; 
          break;
        case 'wrong-password': 
          mensajeError = "Contraseña incorrecta."; 
          break;
        case 'invalid-email': 
          mensajeError = "Formato de correo no válido."; 
          break;
        case 'user-disabled':
          mensajeError = "Esta cuenta ha sido deshabilitada.";
          break;
      }
      _mostrarMensaje(mensajeError);
    } catch (e) {
      _mostrarMensaje("Error de conexión: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          // Degradado que combina con el estilo de la app
          gradient: LinearGradient(
            begin: Alignment.topCenter, 
            end: Alignment.bottomCenter,
            colors: [colors.primaryContainer.withOpacity(0.3), colors.surface],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono representativo de la academia
                Icon(Icons.school_rounded, size: 80, color: colors.primary),
                const SizedBox(height: 20),
                const Text(
                  "EduSpotify", 
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)
                ),
                const Text("Continúa tu aprendizaje"),
                const SizedBox(height: 40),

                // Campo de Correo
                TextField(
                  controller: _emailController, 
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email", 
                    prefixIcon: Icon(Icons.email_outlined), 
                    border: OutlineInputBorder()
                  ),
                ),
                const SizedBox(height: 15),

                // Campo de Contraseña
                TextField(
                  controller: _passwordController, 
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Contraseña", 
                    prefixIcon: Icon(Icons.lock_outline), 
                    border: OutlineInputBorder()
                  ),
                ),
                const SizedBox(height: 30),

                // Botón de Entrar con estado de carga
                if (isLoading) 
                  const CircularProgressIndicator()
                else 
                  SizedBox(
                    width: double.infinity, 
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _login, 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary, 
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: const Text(
                        "Entrar", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      )
                    ),
                  ),

                const SizedBox(height: 15),

                // Botón para alternar a la pantalla de Registro
                TextButton(
                  onPressed: widget.onToggle, 
                  child: const Text("¿No tienes cuenta? Regístrate aquí")
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}