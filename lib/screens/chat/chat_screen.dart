import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Импорт сервиса
import '../../services/order_service.dart';

// Инициализируем OrderService
final OrderService _orderService = OrderService();

// --- Модель сообщения --
class ChatMessage {
  final String senderId;
  final String text;
  final Timestamp timestamp;

  ChatMessage.fromFirestore(Map<String, dynamic> data)
      : senderId = data['sender_id'] ?? '',
        text = data['text'] ?? 'Сообщение отсутствует',
        timestamp = data['timestamp'] ?? Timestamp.now();
}

// --- Экран Чата ---
class ChatScreen extends StatefulWidget {
  final String orderId;
  final String otherUserName; // Имя собеседника (Мастер/Клиент)

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Гарантированно существует, так как мы вошли
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Отправка сообщения в Firestore
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    // Очищаем поле ввода и фокусируемся
    _messageController.clear();
    FocusScope.of(context).unfocus();

    try {
      // ИСПОЛЬЗУЕМ СЕРВИС: отправка сообщения
      await _orderService.sendMessage(
        orderId: widget.orderId,
        text: text,
      );
      // Прокручиваем вниз после отправки (для лучшего UX)
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('Ошибка при отправке сообщения: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось отправить сообщение: ${e.toString()}')),
        );
      }
    }
  }

  // --- Виджет для отображения одного сообщения ---
  Widget _buildMessageBubble(ChatMessage message) {
    final bool isMe = message.senderId == currentUserId;

    // Используем серверное время, но если оно еще не пришло (timestamp is null), используем текущее время
    final timestamp = message.timestamp.toDate();
    final timeFormatted = DateFormat('HH:mm').format(timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
        decoration: BoxDecoration(
            color: isMe ? Colors.teal.shade400 : Colors.grey.shade300,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(15.0),
              topRight: const Radius.circular(15.0),
              bottomLeft: isMe ? const Radius.circular(15.0) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(15.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 3,
                offset: const Offset(0, 1),
              )
            ]
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            // Текст сообщения
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15.0,
              ),
            ),
            const SizedBox(height: 4.0),
            // Время отправки
            Text(
              timeFormatted,
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black54,
                fontSize: 10.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Виджет списка сообщений ---
  Widget _buildMessageList() {
    // ИСПОЛЬЗУЕМ СЕРВИС: получаем поток сообщений
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _orderService.getChatMessagesStream(widget.orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Ошибка при получении сообщений: ${snapshot.error}');
          return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
        }

        final messages = snapshot.data?.docs.map((doc) => ChatMessage.fromFirestore(doc.data())).toList() ?? [];

        if (messages.isEmpty) {
          return const Center(child: Text('Начните чат, отправив первое сообщение!'));
        }

        // ListView.builder в обратном порядке для прокрутки вниз
        return ListView.builder(
          reverse: true, // Показываем последние сообщения внизу
          controller: _scrollController,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return _buildMessageBubble(messages[index]);
          },
        );
      },
    );
  }

  // Виджет поля ввода
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Введите сообщение...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8.0),
          // Кнопка отправки
          FloatingActionButton(
            onPressed: _sendMessage,
            mini: true,
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            elevation: 2,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Чат по заказу', style: TextStyle(fontSize: 16)),
            Text(widget.otherUserName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}