import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:intl/intl.dart';
import '../services/photo_cleaner_service.dart';
import 'group_detail_page.dart';

extension on double {
  double logB(num base) => (log(this) / log(base));
}

class SimilarPhotosPage extends StatefulWidget {
  const SimilarPhotosPage({super.key});

  @override
  State<SimilarPhotosPage> createState() => _SimilarPhotosPageState();
}

class _SimilarPhotosPageState extends State<SimilarPhotosPage> {
  final PhotoCleanerService _photoCleanerService = PhotoCleanerService();
  List<Map<dynamic, dynamic>> _similarGroups = [];
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _scanPhotos() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('We need permission to access your photos.')),
        );
        return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _similarGroups = [];
    });

    try {
      final groups = await _photoCleanerService.findSimilarPhotos();
      setState(() {
        _similarGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
      if (bytes <= 0) return "0 B";
      const suffixes = ["B", "KB", "MB", "GB", "TB"];
      var i = (bytes.toDouble().logB(1024)).floor();
      return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Similar Photo Scanner'),
      ),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _scanPhotos,
                child: const Text('Start Scan'),
              ),
            ),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
              )
            else if (_similarGroups.isEmpty && !_isLoading)
              const Text('No similar photos found.')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _similarGroups.length,
                  itemBuilder: (context, index) {
                    final group = _similarGroups[index];
                    final photoIdentifiers = (group['photoIdentifiers'] as List).cast<String>();
                    final photoCount = photoIdentifiers.length;
                    final totalSize = group['totalSize'] as int;

                    Widget thumbnailPreview;
                    if (photoIdentifiers.isNotEmpty) {
                        thumbnailPreview = SizedBox(
                            width: 56,
                            height: 56,
                            child: Stack(
                                children: [
                                    if (photoIdentifiers.length > 1)
                                        Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: PreviewThumbnail(photoId: photoIdentifiers[1]),
                                        ),
                                    PreviewThumbnail(photoId: photoIdentifiers[0]),
                                ],
                            ),
                        );
                    } else {
                        thumbnailPreview = const SizedBox(width: 56, height: 56); // Placeholder
                    }

                    return ListTile(
                      leading: thumbnailPreview,
                      title: Text('$photoCount similar photos'),
                      subtitle: Text('Total size: ${_formatBytes(totalSize)}'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () async {
                        final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => GroupDetailPage(group: group),
                            ),
                        );
                        if (result == true) { // Group was deleted
                            setState(() {
                                _similarGroups.removeAt(index);
                            });
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PreviewThumbnail extends StatelessWidget {
  final String photoId;
  const PreviewThumbnail({super.key, required this.photoId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.0),
        child: FutureBuilder<Uint8List?>(
          future: AssetEntity.fromId(photoId).then((asset) => asset?.thumbnailDataWithSize(const ThumbnailSize(150, 150))),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
              return Image.memory(snapshot.data!, fit: BoxFit.cover);
            }
            return Container(color: Colors.grey[200]);
          },
        ),
      ),
    );
  }
}
