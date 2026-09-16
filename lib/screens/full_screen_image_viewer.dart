import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

class FullScreenImageViewer extends StatefulWidget {
  final String? imageUrl;
  final String? localPath;
  final String? messageId;

  const FullScreenImageViewer({super.key,
    this.imageUrl,
    this.localPath,
    this.messageId,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  bool _isSaving = false;

  String? get imageUrl => widget.imageUrl;
  String? get localPath => widget.localPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: _buildImage(),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download, color: Colors.white, size: 24),
                ),
                onPressed: _isSaving ? null : _saveImage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);

    try {
      Uint8List bytes;
      if (localPath != null) {
        bytes = await File(localPath!).readAsBytes();
      } else if (imageUrl != null) {
        final response = await http.get(Uri.parse(imageUrl!));
        if (response.statusCode != 200) {
          throw Exception('Preuzimanje nije uspelo (${response.statusCode})');
        }
        bytes = response.bodyBytes;
      } else {
        throw Exception('Nema slike za preuzimanje');
      }

      await Gal.putImageBytes(bytes, name: 'fruitcarepro_${DateTime.now().millisecondsSinceEpoch}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slika sačuvana u galeriju')),
      );
    } on GalException catch (e) {
      if (!mounted) return;
      final message = e.type == GalExceptionType.accessDenied
          ? 'Nema dozvole za pristup galeriji'
          : 'Greška pri čuvanju slike';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Greška pri čuvanju slike'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildImage() {
    if (localPath != null) {
      return Image.file(File(localPath!));
    }
    if (imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
    );
  }
}
