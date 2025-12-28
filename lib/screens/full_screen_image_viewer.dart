import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String? imageUrl;
  final String? localPath;
  final String? messageId; // 🔥 Dodaj messageId

  const FullScreenImageViewer({
    this.imageUrl,
    this.localPath,
    this.messageId,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: const Key('image_viewer'),
      direction: DismissDirection.vertical, // 🔥 Swipe gore/dole da se zatvori
      onDismissed: (_) => Navigator.pop(context),
      background: Container(color: Colors.black),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Slika sa Hero animacijom
            Center(
              child: Hero(
                tag: 'image_$messageId', // 🔥 Isti tag kao u chat-u
                child: InteractiveViewer(
                  child: localPath != null
                      ? Image.file(File(localPath!))
                      : CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                ),
              ),
            ),
            // Close dugme
            SafeArea(
              child: Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
