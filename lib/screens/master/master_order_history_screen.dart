import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- ГЛОБАЛЬНЫЕ КОНСТАНТЫ СРЕДЫ (для Firestore) ---
const String appId =
(String.fromEnvironment('app_id').isNotEmpty && String.fromEnvironment('app_id') != '{{app_id}}')
    ? String.fromEnvironment('app_id')
    : 'default-app-id';

// Модель данных для заказа (повторно используем)
class MasterOrderHistoryModel {
  final String id;
  final String category;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  MasterOrderHistoryModel.fromFirestore(DocumentSnapshot doc)
      : id = doc.id,
        category = doc['category'] ?? 'Не указано',
        description = doc['description'] ?? 'Нет описания',
        status = doc['status'] ?? 'pending',
        createdAt = (doc['created_at'] as Timestamp).toDate(),
        acceptedAt = doc['accepted_at'] != null ? (doc['accepted_at'] as Timestamp).toDate() : null;

  // Визуальное представление статуса
  Color get statusColor {
    switch (status) {
      case 'in_progress':
        return Colors.orange.shade700;
      case 'completed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  String get statusText {
    switch (status) {
      case 'in_progress':
        return 'В РАБОТЕ';
      case 'completed':
        return 'ЗАВЕРШЕН';
      case 'cancelled':
        return 'ОТМЕНЕН';
      default:
        return 'НОВЫЙ';
    }
  }
}

class MasterOrderHistoryScreen extends StatelessWidget {
  const MasterOrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final masterId = user?.uid;

    if (masterId == null) {
      return const Scaffold(
        body: Center(child: Text('Ошибка аутентификации мастера.')),
      );
    }

    // ПУТЬ К ПУБЛИЧНОЙ КОЛЛЕКЦИИ ЗАКАЗОВ
    // Здесь хранятся master_id и обновленный статус
    final publicOrdersPath = 'artifacts/$appId/public/data/orders';

    // Запрос: все заказы, где текущий мастер - исполнитель,
    // и статус не 'pending' (чтобы исключить те, что видны на главном экране)
    final masterOrdersStream = FirebaseFirestore.instance
        .collection(publicOrdersPath)
        .where('master_id', isEqualTo: masterId)
    // Добавляем фильтр, чтобы не показывать заказы в статусе "pending"
        .where('status', isNotEqualTo: 'pending')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои Заказы'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: masterOrdersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки данных: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'У вас пока нет принятых заказов.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final orders = snapshot.data!.docs
              .map((doc) => MasterOrderHistoryModel.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return OrderHistoryCard(order: order);
            },
          );
        },
      ),
    );
  }
}

// Отдельный виджет для карточки истории заказа
class OrderHistoryCard extends StatelessWidget {
  final MasterOrderHistoryModel order;

  const OrderHistoryCard({required this.order, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Категория
                Text(
                  order.category,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Статус
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: order.statusColor, width: 1),
                  ),
                  child: Text(
                    order.statusText,
                    style: TextStyle(
                      color: order.statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 15),

            // Описание
            Text(
              order.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),

            // Время создания и принятия
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 5),
                Text(
                  'Создан: ${order.createdAt.day}.${order.createdAt.month}.${order.createdAt.year}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (order.acceptedAt != null) ...[
                  const SizedBox(width: 15),
                  const Icon(Icons.handshake, size: 14, color: Colors.blueGrey),
                  const SizedBox(width: 5),
                  Text(
                    'Принят: ${order.acceptedAt!.hour}:${order.acceptedAt!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                  ),
                ],
              ],
            ),
            // В реальном приложении здесь были бы кнопки для завершения/оценки
          ],
        ),
      ),
    );
  }
}