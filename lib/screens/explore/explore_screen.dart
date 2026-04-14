import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart' as pdfr; 

// Importaciones de servicios y widgets de Nexo
import '../../services/audio_service.dart';
import '../../widgets/edu_widgets.dart';
import '../../widgets/audio_player_detail.dart';
import '../music/music_screen.dart';
import '../books/book_reader_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _selectedCategory = "Todos";
  String _searchQuery = ""; 
  final TextEditingController _searchController = TextEditingController();
  final audioService = NexoAudioService();

  static const List<Map<String, dynamic>> _categoriesData = [
    {'name': 'Todos', 'icon': Icons.grid_view_rounded},
    {'name': 'Música', 'icon': Icons.music_note_rounded, 'dbType': 'musica'},
    {'name': 'Audiolibros', 'icon': Icons.headphones_rounded, 'dbType': 'audiolibro'},
    {'name': 'Libros', 'icon': Icons.menu_book_rounded, 'dbType': 'libro'},
    {'name': 'Documentos', 'icon': Icons.description_rounded, 'dbType': 'documento'},
    {'name': 'Podcasts', 'icon': Icons.mic_external_on_rounded, 'dbType': 'podcast'},
    {'name': 'Cursos', 'icon': Icons.school_rounded, 'dbType': 'curso'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('music')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          final rawDocs = snapshot.data?.docs ?? [];

          final allDocs = rawDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = (data['title'] ?? '').toString().toLowerCase();
            final author = (data['author'] ?? '').toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return title.contains(query) || author.contains(query);
          }).toList();

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverSafeArea(
                top: true,
                bottom: false,
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Explorar",
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(() => _searchQuery = value),
                            decoration: InputDecoration(
                              hintText: "Busca lecciones, música, audios...",
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty 
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = "");
                                    },
                                  ) 
                                : null,
                              filled: true,
                              fillColor: colors.surfaceContainerHighest.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: _categoriesData.length,
                    itemBuilder: (context, index) {
                      final cat = _categoriesData[index];
                      final isSelected = _selectedCategory == cat['name'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat['name']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.primary : colors.surfaceContainerHighest.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            children: [
                              Icon(cat['icon'], size: 18, color: isSelected ? Colors.white : colors.primary),
                              const SizedBox(width: 8),
                              Text(cat['name'], style: TextStyle(color: isSelected ? Colors.white : colors.onSurfaceVariant, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 25)),

              if (_searchQuery.isNotEmpty)
                 _buildSearchResultsGrid(allDocs, colors)
              else if (_selectedCategory == "Todos")
                ..._buildAllSections(allDocs, colors)
              else
                _buildFilteredGrid(allDocs, colors),

              const SliverToBoxAdapter(child: SizedBox(height: 150)), 
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchResultsGrid(List<QueryDocumentSnapshot> docs, ColorScheme colors) {
    if (docs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.65, 
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildContentCard(docs[index].data() as Map<String, dynamic>, docs, index, isGrid: true),
          childCount: docs.length,
        ),
      ),
    );
  }

  List<Widget> _buildAllSections(List<QueryDocumentSnapshot> docs, ColorScheme colors) {
    final List<Widget> sections = [];
    final categoriesToDisplay = _categoriesData.where((c) => c['name'] != 'Todos');

    for (var cat in categoriesToDisplay) {
      final categoryDocs = docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        final String? type = data['type'];
        return (cat['dbType'] == 'musica') ? (type == 'musica' || type == null) : (type == cat['dbType'] || (cat['dbType'] == 'documento' && type == 'ensayo'));
      }).toList();

      if (categoryDocs.isNotEmpty) {
        sections.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(cat['name'], () => setState(() => _selectedCategory = cat['name'])),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: (cat['dbType'] == 'documento') ? 260 : 210,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categoryDocs.length,
                      itemBuilder: (context, index) => _buildContentCard(categoryDocs[index].data() as Map<String, dynamic>, categoryDocs, index),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return sections;
  }

  Widget _buildFilteredGrid(List<QueryDocumentSnapshot> docs, ColorScheme colors) {
    final currentCat = _categoriesData.firstWhere((c) => c['name'] == _selectedCategory);
    final filteredDocs = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final String? type = data['type'];
      return (currentCat['dbType'] == 'musica') ? (type == 'musica' || type == null) : (type == currentCat['dbType'] || (currentCat['dbType'] == 'documento' && type == 'ensayo'));
    }).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildContentCard(filteredDocs[index].data() as Map<String, dynamic>, filteredDocs, index, isGrid: true),
          childCount: filteredDocs.length,
        ),
      ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> data, List<QueryDocumentSnapshot> list, int index, {bool isGrid = false}) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String title = data['title'] ?? 'Sin título';
    final String author = data['author'] ?? 'Autor desconocido';
    final dynamic coverUrl = data['coverUrl'];
    final String url = data['url'] ?? '';
    final bool isYouTube = data['isYouTube'] ?? false;
    final String type = data['type'] ?? 'musica';
    final String docId = list[index].id;

    final bool isDocument = type == 'documento' || type == 'ensayo';
    final bool isBook = type == 'libro';
    final bool isPodcast = type == 'podcast';

    final bool hasCover = coverUrl != null && coverUrl.toString().isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (isBook || isDocument) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => BookReaderScreen(url: url, title: title)));
        } else {
          // Lógica unificada para Música, Audiolibros y PODCASTS
          audioService.setPlaylist(list.map((e) => e.data() as Map<String, dynamic>).toList(), index);
          audioService.playNew(url, title, author, coverUrl ?? '', youtube: isYouTube);
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => AudioPlayerDetail(
                title: title, 
                author: author, 
                imageUrl: coverUrl ?? '', 
                videoUrl: url, 
                isYouTube: isYouTube
              )
            )
          );
        }
      },
      child: Container(
        width: isGrid ? null : 150,
        margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(right: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), width: 1),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (isDocument && !hasCover)
                        DocumentAutoThumbnail(url: url, docId: docId)
                      else
                        Image.network(
                          hasCover ? coverUrl.toString() : 'https://images.unsplash.com/photo-1507838153414-b4b713384a76?q=80&w=1000&auto=format&fit=crop',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.picture_as_pdf, color: Colors.white24, size: 40)),
                        ),

                      Container(color: Colors.black.withOpacity(0.05)),
                      if (isYouTube && !isDocument)
                        const Center(child: Icon(Icons.play_circle_filled, color: Colors.white, size: 40)),
                      
                      Positioned(
                        top: 10, right: 10,
                        child: Icon(
                          isBook ? Icons.menu_book_rounded : (isDocument ? Icons.description_rounded : (isPodcast ? Icons.mic_rounded : Icons.music_note)),
                          size: 18, color: isPodcast ? Colors.indigoAccent : Colors.orange.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(author, style: TextStyle(color: colors.primary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        TextButton(onPressed: onSeeAll, child: const Text("Ver todo", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
      ],
    );
  }
}

class DocumentAutoThumbnail extends StatefulWidget {
  final String url;
  final String docId;
  const DocumentAutoThumbnail({super.key, required this.url, required this.docId});

  @override
  State<DocumentAutoThumbnail> createState() => _DocumentAutoThumbnailState();
}

class _DocumentAutoThumbnailState extends State<DocumentAutoThumbnail> {
  Uint8List? _thumbnailBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchAndRender();
  }

  Future<void> _fetchAndRender() async {
    if (!mounted) return;
    try {
      final response = await http.get(Uri.parse(widget.url)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw "Error de descarga";

      final document = await pdfr.PdfDocument.openData(response.bodyBytes);
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width * 1.5,
        height: page.height * 1.5,
        format: pdfr.PdfPageImageFormat.jpeg,
        quality: 80,
      );

      final bytes = pageImage?.bytes;
      if (bytes == null) throw "Error al renderizar";

      _autoUpdateCloudCover(bytes);

      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
          _isLoading = false;
        });
      }

      await page.close();
      await document.close();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _autoUpdateCloudCover(Uint8List bytes) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('document_thumbnails').child('${widget.docId}.jpg');
      await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance.collection('music').doc(widget.docId).set({'coverUrl': downloadUrl}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("⚠️ Error al persistir miniatura: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    if (_hasError || _thumbnailBytes == null) return Container(color: Colors.white10, child: const Center(child: Icon(Icons.picture_as_pdf, color: Colors.white24, size: 40)));
    return Image.memory(_thumbnailBytes!, fit: BoxFit.cover);
  }
}