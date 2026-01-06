// lib/exceptions/chat_exceptions.dart

/// Base exception for chat-related errors
abstract class ChatException implements Exception {
  final String message;

  ChatException(this.message);

  @override
  String toString() => message;
}

/// Thrown when sending a message fails
class SendMessageException extends ChatException {
  SendMessageException(super.message);
}

/// Thrown when creating a chat fails
class CreateChatException extends ChatException {
  CreateChatException(super.message);
}

/// Thrown when uploading an image fails
class ImageUploadException extends ChatException {
  ImageUploadException(super.message);
}