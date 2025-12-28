import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final Map<String, dynamic> messageData;
  final bool isCurrentUser;
  final VoidCallback? onImageTap;
  final String otherUserId; // 🔥 Bilo adminId, sada generički

  const ChatBubble({
    super.key,
    required this.messageData,
    required this.isCurrentUser,
    required this.otherUserId,
    this.onImageTap,
  });

   @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
              minWidth: MediaQuery.of(context).size.width * 0.2,
            ),
            child: IntrinsicWidth(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.green[600] : Colors.brown[500],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: isCurrentUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (_hasImage) _buildImage(),
                    if (_hasText) ...[
                      if (_hasImage) const SizedBox(height: 8),
                      _buildText(),
                    ],
                    const SizedBox(height: 4),
                    _buildTimestampWithStatus(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasImage =>
      messageData['thumbUrl'] != null || 
      messageData['localImagePath'] != null ||
      messageData['isUploading'] == true;

  bool get _hasText => (messageData['message'] as String?)?.isNotEmpty ?? false;

Widget _buildImage() {
  final isUploading = messageData['isUploading'] ?? false;
  final uploadFailed = messageData['uploadFailed'] ?? false;
  final uploadProgress = (messageData['uploadProgress'] ?? 0.0) as double;
  final hasThumb = messageData['thumbUrl'] != null;

  // Prikaži loader SAMO ako nema thumbnail-a
  if (isUploading && !hasThumb) {
    return _buildUploadingImage(uploadProgress);
  }

  // Prikaži error SAMO ako nema ni thumb
  if (uploadFailed && !hasThumb) {
    return _buildFailedImage();
  }

  final messageId = messageData['messageId'] as String?;

  // Prikaži sliku BEZ mini loadera
  return GestureDetector(
    onTap: onImageTap,
    child: Hero(
      tag: 'image_$messageId', // 🔥 Unique tag
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImageWidget(),
      ),
    ),
  );
  // ❌ UKLONI Stack sa mini loader-om
}

// 🔥 Loading state sa progress bar-om
Widget _buildUploadingImage(double progress) {
  final localPath = messageData['localImagePath'] as String?;
  
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      height: 200,
      // ❌ UKLONI width: double.infinity jer si unutar IntrinsicWidth
      child: Stack(
        children: [
          // Prikaži lokalnu sliku (blur)
          if (localPath != null)
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.3),
                BlendMode.darken,
              ),
              child: Image.file(
                File(localPath),
                height: 200,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 200,
              color: Colors.grey[300],
            ),
          
          // Loading overlay
          Positioned.fill(
            child: Container(
              color: Colors.black38,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      backgroundColor: Colors.white30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    progress > 0 
                      ? '${(progress * 100).toInt()}%'
                      : 'Učitavanje...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// 🔥 Failed state - takođe ukloni width
Widget _buildFailedImage() {
  return Container(
    height: 200,
    // ❌ UKLONI width: double.infinity
    decoration: BoxDecoration(
      color: Colors.red[100],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red[700]),
        const SizedBox(height: 8),
        Text(
          'Upload nije uspeo',
          style: TextStyle(
            color: Colors.red[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            // TODO: Implementiraj retry logiku
            print('Retry upload');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Pokušaj ponovo'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red[700],
          ),
        ),
      ],
    ),
  );
}
Widget _buildImageWidget() {
  final thumbUrl = messageData['thumbUrl'] as String?;
  final localPath = messageData['localImagePath'] as String?;

  // 🔥 Uvek prikaži samo THUMBNAIL u chat-u
  if (thumbUrl != null) {
    return CachedNetworkImage(
      imageUrl: thumbUrl,
      height: 200,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 300),
    );
  }

  if (localPath != null) {
    return Image.file(
      File(localPath),
      height: 200,
      fit: BoxFit.cover,
    );
  }

  return _buildDefaultImage();
}

  Widget _buildErrorWidget() {
    return Container(
      height: 200,
      color: Colors.grey,
      child: const Icon(Icons.error, color: Colors.red),
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      height: 200,
      color: Colors.grey[300],
      child: const Icon(Icons.image, color: Colors.white, size: 50),
    );
  }

  Widget _buildTimestampWithStatus() {
    final timestamp = messageData['timestamp'] as Timestamp?;
    if (timestamp == null) return const SizedBox.shrink();

    final time = timestamp.toDate();
    final formattedTime =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formattedTime,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
        // Prikaži kukice samo za poruke trenutnog korisnika
        if (isCurrentUser) ...[
          const SizedBox(width: 4),
          _buildReadStatusIcon(),
        ],
      ],
    );
  }

  Widget _buildText() {
    return Text(
      messageData['message'],
      style: const TextStyle(color: Colors.white),
    );
  }


  Widget _buildReadStatusIcon() {
    final readBy = messageData['readBy'] as Map<String, dynamic>? ?? {};
    final isReadByOther = readBy.containsKey(otherUserId); // 🔥 Ovde promeni

    if (isReadByOther) {
      return Icon(Icons.done_all, size: 16, color: Colors.blue[300]);
    }

    return Icon(
      Icons.done_all,
      size: 16,
      color: Colors.white.withOpacity(0.6),
    );
  }
}

