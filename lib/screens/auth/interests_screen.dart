import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  // OPTIMIZACIÓN 120HZ: Lista estática inmutable para evitar recreación de objetos en el build
  static const List<Map<String, dynamic>> _categories = [
    {'name': 'Ciencia', 'icon': Icons.science, 'color': Colors.blue},
    {'name': 'Historia', 'icon': Icons.history_edu, 'color': Colors.orange},
    {'name': 'Matemáticas', 'icon': Icons.functions, 'color': Colors.green},
    {'name': 'Arte', 'icon': Icons.palette, 'color': Colors.purple},
    {'name': 'Música', 'icon': Icons.music_note, 'color': Colors.pink},
    {'name': 'Tecnología', 'icon': Icons.biotech, 'color': Colors.teal},
    {'name': 'Literatura', 'icon': Icons.menu_book, 'color': Colors.brown},
    {'name': 'Idiomas', 'icon': Icons.translate, 'color': Colors.indigo},
  ];

  final List<String> selectedInterests = [];
  bool isSaving = false;

  void toggleInterest(String name) {
    setState(() {
      if (selectedInterests.contains(name)) {
        selectedInterests.remove(name);
      } else {
        selectedInterests.add(name);
      }
    });
  }

  Future<void> saveInterests() async {
    if (selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Selecciona al menos un interés para continuar"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'interests': selectedInterests,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "¿Qué quieres aprender?",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Selecciona tus temas favoritos para personalizar tu experiencia educativa.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              
              // OPTIMIZACIÓN 120HZ: RepaintBoundary para aislar el renderizado del GridView
              Expanded(
                child: RepaintBoundary(
                  child: GridView.builder(
                    // OPTIMIZACIÓN: Física nativa de Android para un comportamiento profesional
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = selectedInterests.contains(cat['name']);
                      
                      return GestureDetector(
                        onTap: () => toggleInterest(cat['name']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic, 
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? cat['color'] 
                                : colors.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? cat['color'] : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: (cat['color'] as Color).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ] : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cat['icon'],
                                size: 40,
                                color: isSelected ? Colors.white : cat['color'],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                cat['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: (selectedInterests.isEmpty || isSaving) ? null : saveInterests,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colors.surfaceContainerHighest,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Comenzar aventura",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}