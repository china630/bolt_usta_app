import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Chat Message Model
class ChatMessage {
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isMaster;

  ChatMessage({
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMaster,
  });

  factory ChatMessage.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      senderId: data['sender_id'] ?? '',
      text: data['text'] ?? '',
      // Используем безопасный доступ к timestamp
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMaster: data['is_master'] ?? false,
    );
  }
}

class ChatComponent extends StatefulWidget {
  final String orderId;
  final bool isMasterContext; // True, если чат открыт мастером

  const ChatComponent({
    super.key,
    required this.orderId,
    required this.isMasterContext,
  });

  @override
  State<ChatComponent> createState() => _ChatComponentState();
}

class _ChatComponentState extends State<ChatComponent> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Автоматическая прокрутка вниз
  void _scrollToBottom() {
    // Прокручиваем только если контроллер уже присоединен к ListView
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Функция для отправки сообщения
  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty || _currentUserId == null) {
      return;
    }

    final text = _textController.text.trim();
    _textController.clear();

    // Прокрутка перед/после отправкой для лучшего UX
    await Future.delayed(const Duration(milliseconds: 50));
    _scrollToBottom();

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .collection('messages') // Сообщения хранятся как подколлекция заказа
          .add({
        'sender_id': _currentUserId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'is_master': widget.isMasterContext,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки сообщения: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text("Ошибка аутентификации чата."));
    }

    return Column(
      children: [
        // Message List Stream
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .doc(widget.orderId)
                .collection('messages')
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Ошибка загрузки сообщений: ${snapshot.error}'));
              }

              final messages = snapshot.data!.docs
                  .map((doc) => ChatMessage.fromDocument(doc))
                  .toList();

              // Прокрутка вниз после загрузки или обновления
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(messages[index]);
                },
              );
            },
          ),
        ),

        // Message Input
        _buildMessageInput(),
      ],
    );
  }

  // Message Bubble Widget
  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.senderId == _currentUserId;
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final color = isMe ? Colors.blue.shade600 : Colors.grey.shade300;
    final textColor = isMe ? Colors.white : Colors.black87;
    final senderLabel = message.isMaster ? 'Мастер' : 'Клиент';

    // Форматируем время
    final timeFormat = DateFormat('HH:mm');
    final timeString = timeFormat.format(message.timestamp);

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 2, left: 10, right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 15 : 0),
            topRight: Radius.circular(isMe ? 0 : 15),
            bottomLeft: const Radius.circular(15),
            bottomRight: const Radius.circular(15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Подпись отправителя
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  senderLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.indigo.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 16),
            ),

            const SizedBox(height: 5),

            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeString,
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Message Input Widget
  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 15.0),
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Введите сообщение...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.4),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}