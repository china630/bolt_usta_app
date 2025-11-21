import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message_model.dart';

class ChatService {
  // Получаем экземпляры Firestore и Auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Метод для отправки сообщения
  Future<void> sendMessage(String orderId, String text) async {
    // Получаем ID текущего пользователя
    final currentUserId = _auth.currentUser!.uid;

    // Создаем экземпляр сообщения, используя серверное время через toJson()
    final newMessage = ChatMessageModel(
      senderId: currentUserId,
      text: text,
      // Временная метка не нужна здесь, так как она будет установлена сервером через FieldValue.serverTimestamp()
      timestamp: DateTime.now(),
    );

    // Ссылка на коллекцию сообщений для данного заказа
    final chatCollection = _firestore
        .collection('orders')
        .doc(orderId)
        .collection('chat');

    // Добавляем сообщение в коллекцию
    await chatCollection.add(newMessage.toJson());
  }

  // 2. Метод для получения потока сообщений (Stream)
  Stream<List<ChatMessageModel>> getMessages(String orderId) {
    // Ссылка на коллекцию сообщений
    final chatCollection = _firestore
        .collection('orders')
        .doc(orderId)
        .collection('chat')
    // Сортируем по времени, чтобы новые сообщения были внизу
        .orderBy('timestamp', descending: false);

    // Возвращаем Stream, который автоматически преобразует QuerySnapshot в List<ChatMessageModel>
    return chatCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        // Преобразуем данные документа в модель ChatMessageModel
        return ChatMessageModel.fromJson(doc.data());
      }).toList();
    });
  }
}