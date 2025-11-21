import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String senderId;
  final String text;
  final DateTime timestamp;

  ChatMessageModel({
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  // --- Фабричный конструктор для создания модели из Map (из Firestore) ---
  factory ChatMessageModel.fromJson(Map<String, dynamic> data) {
    return ChatMessageModel(
      senderId: data['sender_id'] ?? '',
      text: data['text'] ?? '',
      // Безопасное преобразование Timestamp в DateTime
      timestamp: (data['timestamp'] is Timestamp)
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(), // Fallback (если поле отсутствует или некорректно)
    );
  }

  // --- Метод для преобразования в Map (для записи в Firestore) ---
  Map<String, dynamic> toJson() {
    return {
      'sender_id': senderId,
      'text': text,
      // Используем серверное время для автоматического создания поля на стороне сервера
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}