import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/photo_cleaner_service.dart';

class GroupDetailPage extends StatelessWidget {
  final Map<dynamic, dynamic> group;

  const GroupDetailPage({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text('Group Details'),
        ),
        body: PhotoGroupCard(group: group, onDeleted: () {
            Navigator.pop(context, true); // Return true to signal deletion
        }),
    );
  }
}

class PhotoGroupCard extends StatefulWidget {
  final Map<dynamic, dynamic> group;
  final VoidCallback onDeleted;

  const PhotoGroupCard({super.key, required this.group, required this.onDeleted});

  @override
  State<PhotoGroupCard> createState() => _PhotoGroupCardState();
}

class _PhotoGroupCardState extends State<PhotoGroupCard> {
  late Set<String> _selectedForDeletion;
  String? _bestPhotoId; // Holds the identifier of the best photo, calculated on demand
  final PhotoCleanerService _photoCleanerService = PhotoCleanerService();

  @override
  void initState() {
    super.initState();
    final allPhotoIds = (widget.group['photoIdentifiers'] as List<dynamic>).cast<String>();
    // Initially, select all photos for deletion. The best photo will be deselected once calculated.
    _selectedForDeletion = Set.from(allPhotoIds);
    _calculateBestPhoto(allPhotoIds);
  }

  Future<void> _calculateBestPhoto(List<String> photoIds) async {
    try {
      // This is a new method you need to add to your PhotoCleanerService
      final bestId = await _photoCleanerService.recommendBestPhoto(photoIds);
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _bestPhotoId = bestId;
          // Once the best photo is known, unselect it from the deletion list
          _selectedForDeletion.remove(bestId);
        });
      }
    } catch (e) {
      print('Failed to recommend best photo: $e');
      // Handle error, maybe show a toast or default to no best photo
    }
  }

  void _toggleSelection(String photoId) {
    setState(() {
      if (_selectedForDeletion.contains(photoId)) {
        _selectedForDeletion.remove(photoId);
      } else {
        _selectedForDeletion.add(photoId);
      }
    });
  }

  Future<void> _deleteSelectedPhotos() async {
    try {
      await _photoCleanerService.deletePhotos(_selectedForDeletion.toList());
      widget.onDeleted();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${_selectedForDeletion.length} photos.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete photos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPhotoIds = (widget.group['photoIdentifiers'] as List<dynamic>).cast<String>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedForDeletion.length} of ${allPhotoIds.length - 1} selected for deletion',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                  onPressed: _deleteSelectedPhotos,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(4.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4.0,
              mainAxisSpacing: 4.0,
            ),
            itemCount: allPhotoIds.length,
            itemBuilder: (context, index) {
              final photoId = allPhotoIds[index];
              final isBest = photoId == _bestPhotoId;
              final isSelected = _selectedForDeletion.contains(photoId);

              return PhotoThumbnail(
                  photoId: photoId,
                  isBest: isBest,
                  isSelected: isSelected,
                  onSelectToggle: () => _toggleSelection(photoId),
                  onTapImage: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) {
                          return PhotoViewerPage(
                              photoIds: allPhotoIds,
                              initialIndex: index,
                              selectedIds: _selectedForDeletion,
                              onSelectionChanged: (id) => _toggleSelection(id),
                              bestPhotoId: _bestPhotoId ?? '',
                          );
                      }));
                      setState(() {}); // Refresh selection state after returning from viewer
                  },
              );
            },
          ),
        ),
      ],
    );
  }
}

class PhotoThumbnail extends StatefulWidget {
    final String photoId;
    final bool isBest;
    final bool isSelected;
    final VoidCallback onSelectToggle;
    final VoidCallback onTapImage;

    const PhotoThumbnail({
        super.key,
        required this.photoId,
        required this.isBest,
        required this.isSelected,
        required this.onSelectToggle,
        required this.onTapImage,
    });

    @override
    State<PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<PhotoThumbnail> {
    late Future<Uint8List?> _thumbnailFuture;

    @override
    void initState() {
        super.initState();
        _thumbnailFuture = _loadThumbnail();
    }

    Future<Uint8List?> _loadThumbnail() async {
        final asset = await AssetEntity.fromId(widget.photoId);
        if (asset != null) {
            return await asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
        }
        return null;
    }

    @override
    Widget build(BuildContext context) {
        return GestureDetector(
            onTap: widget.onTapImage,
            child: Stack(
                fit: StackFit.expand,
                children: [
                    FutureBuilder<Uint8List?>(
                        future: _thumbnailFuture,
                        builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                                return Image.memory(snapshot.data!, fit: BoxFit.cover);
                            }
                            return const Center(child: CircularProgressIndicator());
                        },
                    ),
                    if (widget.isBest)
                        Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                color: Colors.green.withOpacity(0.8),
                                child: const Text('BEST', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ),
                    Positioned(
                        top: 4,
                        left: 4,
                        child: SelectionCheckbox(
                            isSelected: widget.isSelected,
                            onTap: widget.onSelectToggle,
                        ),
                    ),
                ],
            ),
        );
    }
}

// New widget to handle selection state locally and improve performance
class SelectionCheckbox extends StatelessWidget {
    final bool isSelected;
    final VoidCallback onTap;

    const SelectionCheckbox({super.key, required this.isSelected, required this.onTap});

    @override
    Widget build(BuildContext context) {
        return GestureDetector(
            onTap: onTap,
            child: Container(
                // Make the tap area larger without changing the visual size of the circle
                padding: const EdgeInsets.all(8.0),
                color: Colors.transparent, // Ensures the padding area is tappable
                child: Container(
                    decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : const Icon(null, size: 16),
                    ),
                ),
            ),
        );
    }
}

class PhotoViewerPage extends StatefulWidget {
  final List<String> photoIds;
  final int initialIndex;
  final Set<String> selectedIds;
  final Function(String) onSelectionChanged;
  final String bestPhotoId;

  const PhotoViewerPage({
      super.key,
      required this.photoIds,
      required this.initialIndex,
      required this.selectedIds,
      required this.onSelectionChanged,
      required this.bestPhotoId,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photoIds.length,
            onPageChanged: (index) {
                setState(() {
                    _currentIndex = index;
                });
            },
            itemBuilder: (context, index) {
              // Use the new stateful widget to prevent image reloading on setState
              return PhotoViewerItem(photoId: widget.photoIds[index]);
            },
          ),
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
                onTap: () {
                    widget.onSelectionChanged(widget.photoIds[_currentIndex]);
                    // This setState will now only rebuild the checkbox, not the image viewer
                    setState(() {});
                },
                child: Container(
                    decoration: BoxDecoration(
                        color: widget.selectedIds.contains(widget.photoIds[_currentIndex]) ? Colors.blue : Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: widget.selectedIds.contains(widget.photoIds[_currentIndex])
                            ? const Icon(Icons.check, color: Colors.white, size: 24)
                            : const Icon(null, size: 24),
                    ),
                ),
            ),
          ),
          if (widget.photoIds[_currentIndex] == widget.bestPhotoId)
            Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('BEST', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                ),
            ),
        ],
      ),
    );
  }
}

// New StatefulWidget to display a single photo in the viewer.
// It caches the image future to prevent reloading on parent rebuilds.
class PhotoViewerItem extends StatefulWidget {
  final String photoId;

  const PhotoViewerItem({super.key, required this.photoId});

  @override
  State<PhotoViewerItem> createState() => _PhotoViewerItemState();
}

class _PhotoViewerItemState extends State<PhotoViewerItem> {
  late Future<Uint8List?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _loadImage();
  }

  Future<Uint8List?> _loadImage() async {
    final asset = await AssetEntity.fromId(widget.photoId);
    return asset?.originBytes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return InteractiveViewer(
            child: Image.memory(snapshot.data!),
          );
        }
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      },
    );
  }
}
