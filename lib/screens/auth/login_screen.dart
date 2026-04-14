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
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _mostrarMensaje("Por favor, llena todos los campos.");
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String mensajeError = "Ocurrió un error inesperado.";
      
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : colors.surface,
      // OPTIMIZACIÓN 120HZ: RepaintBoundary para aislar el degradado de fondo
      body: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, 
              end: Alignment.bottomCenter,
              colors: [
                colors.primaryContainer.withOpacity(isDark ? 0.15 : 0.3), 
                isDark ? Colors.black : colors.surface
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              // OPTIMIZACIÓN: Se restaura la física nativa de Android (Stretch/Glow)
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school_rounded, size: 80, color: Colors.blue),
                  const SizedBox(height: 20),
                  const Text(
                    "Nexo", 
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)
                  ),
                  const Text("Continúa tu aprendizaje"),
                  const SizedBox(height: 40),

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

                  // Botón de Entrar con optimización de layout
                  SizedBox(
                    width: double.infinity, 
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _login, 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary, 
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: isLoading 
                        ? const SizedBox(
                            height: 20, 
                            width: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          )
                        : const Text(
                            "Entrar", 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                          )
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextButton(
                    onPressed: widget.onToggle, 
                    child: const Text("¿No tienes cuenta? Regístrate aquí")
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}