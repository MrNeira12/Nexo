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

  // Seleccionar foto para el registro
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _register() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por favor llena todos los campos")));
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

      // 3. Crear el documento del usuario en Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'photoUrl': photoUrl ?? '', // Si no hay foto, se guarda vacío
        'interests': [], // Lista vacía para que luego vaya a la pantalla de intereses
        'level': 'Estudiante Novato',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // No necesitamos navegar manualmente, el AuthWrapper de main.dart detectará el nuevo usuario
    } on FirebaseAuthException catch (e) {
      String msg = "Error al registrarse";
      if (e.code == 'email-already-in-use') msg = "Este correo ya está registrado";
      if (e.code == 'weak-password') msg = "La contraseña es muy débil";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Únete a EduSpotify", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Tu viaje educativo comienza aquí"),
              const SizedBox(height: 30),
              
              // Selector de Foto Circular
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: colors.primary.withOpacity(0.1),
                  backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                  child: _imageFile == null ? const Icon(Icons.add_a_photo, size: 40) : null,
                ),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nombre completo", prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Correo electrónico", prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 30),

              _isLoading 
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: Colors.white),
                      child: const Text("Registrarse", style: TextStyle(fontSize: 18)),
                    ),
                  ),
              const SizedBox(height: 15),
              TextButton(onPressed: widget.onToggle, child: const Text("¿Ya tienes cuenta? Inicia sesión")),
            ],
          ),
        ),
      ),
    );
  }
}