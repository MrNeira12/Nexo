import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onToggle;
  const RegisterScreen({super.key, required this.onToggle});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  File? _imageFile;
  bool _isLoading = false;

  // Seleccionar foto para el registro en Nexo
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _register() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor llena todos los campos"), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Crear el usuario en Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String? photoUrl;

      // 2. Si eligió foto, subirla a Storage
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_photos')
            .child('${userCredential.user!.uid}.jpg');
        await ref.putFile(_imageFile!);
        photoUrl = await ref.getDownloadURL();
      }

      // 3. Crear el documento del usuario en Firestore bajo la estructura de Nexo
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'photoUrl': photoUrl ?? '', 
        'interests': [], 
        'level': 'Estudiante Novato',
        'createdAt': FieldValue.serverTimestamp(),
      });

    } on FirebaseAuthException catch (e) {
      String msg = "Error al registrarse";
      if (e.code == 'email-already-in-use') msg = "Este correo ya está registrado";
      if (e.code == 'weak-password') msg = "La contraseña es muy débil";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : colors.surface,
      // OPTIMIZACIÓN 120HZ: RepaintBoundary para aislar el renderizado del formulario
      body: RepaintBoundary(
        child: Center(
          child: SingleChildScrollView(
            // OPTIMIZACIÓN: Se restaura la física nativa de Android (Stretch/Glow)
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Únete a Nexo", 
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 10),
                const Text(
                  "Tu viaje educativo comienza aquí",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                
                // Selector de Foto Circular con decoración optimizada
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: colors.primary.withOpacity(0.1),
                        backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                        child: _imageFile == null 
                            ? Icon(Icons.person_add_alt_1_rounded, size: 45, color: colors.primary) 
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: colors.primary,
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: "Nombre completo", 
                    prefixIcon: Icon(Icons.person_outline), 
                    border: OutlineInputBorder()
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Correo electrónico", 
                    prefixIcon: Icon(Icons.email_outlined), 
                    border: OutlineInputBorder()
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: "Contraseña", 
                    prefixIcon: Icon(Icons.lock_outline), 
                    border: OutlineInputBorder()
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 35),

                // Botón de Registro optimizado para evitar saltos de layout
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary, 
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: _isLoading 
                      ? const SizedBox(
                          height: 20, 
                          width: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                        )
                      : const Text(
                          "Registrarse", 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                        ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: widget.onToggle, 
                  child: const Text("¿Ya tienes cuenta? Inicia sesión")
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}