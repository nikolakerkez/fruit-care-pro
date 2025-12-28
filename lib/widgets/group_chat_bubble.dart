import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GroupChatBubble extends StatelessWidget {
  final Map<String, dynamic> messageData;
  final bool isCurrentUser;
  final bool isAdmin;
  final Timestamp? userLastMessageTimestamp;
  final VoidCallback? onImageTap;

  const GroupChatBubble({
    super.key,
    required this.messageData,
    required this.isCurrentUser,
    required this.isAdmin,
    required this.userLastMessageTimestamp,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = messageData['thumbUrl'] != null || 
                      messageData['localImagePath'] != null;

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
                  color: isCurrentUser 
                      ? Colors.green[800] 
                      : Colors.orangeAccent[400],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: isCurrentUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (hasImage) _buildImage(),
                    if (_hasText) ...[
                      if (hasImage) const SizedBox(height: 8),
                      Text(
                        messageData['message'],
                        style: const TextStyle(color: Colors.white),
                      ),
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

  bool get _hasText => (messageData['message'] as String?)?.isNotEmpty ?? false;

  Widget _buildImage() {
    final isUploading = messageData['isUploading'] ?? false;
    final uploadFailed = messageData['uploadFailed'] ?? false;
    final hasThumb = messageData['thumbUrl'] != null;

    if (isUploading && !hasThumb) {
      return _buildUploadingImage();
    }

    if (uploadFailed && !hasThumb) {
      return _buildFailedImage();
    }

    final messageId = messageData['messageId'] as String?;

    return GestureDetector(
      onTap: onImageTap,
      child: Hero(
        tag: 'image_$messageId',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildImageWidget(),
        ),
      ),
    );
  }

  Widget _buildUploadingImage() {
    final localPath = messageData['localImagePath'] as String?;
    final uploadProgress = (messageData['uploadProgress'] ?? 0.0) as double;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
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
                        value: uploadProgress > 0 ? uploadProgress : null,
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        backgroundColor: Colors.white30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      uploadProgress > 0
                          ? '${(uploadProgress * 100).toInt()}%'
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

  Widget _buildFailedImage() {
    return Container(
      height: 200,
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
              // TODO: Retry upload
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

    if (thumbUrl != null) {
      return Image.network(
        thumbUrl,
        height: 200,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            color: Colors.grey,
            child: const Icon(Icons.error, color: Colors.red),
          );
        },
      );
    }

    if (localPath != null) {
      return Image.file(
        File(localPath),
        height: 200,
        fit: BoxFit.cover,
      );
    }

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
        if (isAdmin && _shouldShowReadIcon(timestamp)) ...[
          const SizedBox(width: 4),
          _buildReadStatusIcon(),
        ],
      ],
    );
  }

  bool _shouldShowReadIcon(Timestamp timestamp) {
    if (userLastMessageTimestamp == null) return false;
    return userLastMessageTimestamp!.compareTo(timestamp) < 0;
  }

  Widget _buildReadStatusIcon() {
    final isRead = messageData['isRead'] ?? false;

    return Icon(
      isRead ? Icons.check_circle : Icons.check_circle_outline,
      color: Colors.white,
      size: 16,
    );
  }
}