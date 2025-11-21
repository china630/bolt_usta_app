import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:on_demand_service_app/components/chat_component.dart'; // Новый импорт для чата
import 'package:firebase_auth/firebase_auth.dart';

// Обновляем MasterActiveOrderScreen, чтобы использовать TabBar
class MasterActiveOrderScreen extends StatelessWidget {
  final String orderId;

  const MasterActiveOrderScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    // Слушаем данные заказа
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            appBar: null,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Заказ не найден')),
            body: const Center(child: Text('Заказ был отменен или удален.')),
          );
        }

        final orderData = snapshot.data!.data() as Map<String, dynamic>;
        final status = orderData['status'] ?? 'unknown';

        // Проверяем, что заказ все еще наш и активен
        if (status == 'completed' || status == 'cancelled') {
          // Если статус изменился, автоматически закрываем экран
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Заказ завершен или отменен. Статус: $status')),
            );
          });
          return Scaffold(
            appBar: AppBar(title: const Text('Статус изменен')),
            body: const Center(child: Text('Перенаправление...')),
          );
        }

        // Используем DefaultTabController для навигации между деталями и чатом
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Активный Заказ'),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              bottom: const TabBar(
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Детали', icon: Icon(Icons.info_outline)),
                  Tab(text: 'Чат', icon: Icon(Icons.message)),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // 1. Детали Заказа
                _buildOrderDetailsTab(context, orderId, status, orderData),

                // 2. Чат - используем новый компонент
                ChatComponent(
                  orderId: orderId,
                  isMasterContext: true, // Флаг, что это чат мастера
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Таб с Деталями Заказа ---
  Widget _buildOrderDetailsTab(BuildContext context, String orderId, String status, Map<String, dynamic> orderData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBanner(status),
          const SizedBox(height: 20),

          // Детали заказа
          _buildDetailCard(
            title: 'Категория',
            value: orderData['category'] ?? 'N/A',
            icon: Icons.category,
          ),
          _buildDetailCard(
            title: 'Описание Задачи',
            value: orderData['description'] ?? 'Нет описания',
            icon: Icons.description,
            isLongText: true,
          ),
          _buildDetailCard(
            title: 'Бюджет',
            value: 'от ${orderData['budget_min'] ?? 'N/A'} до ${orderData['budget_max'] ?? 'N/A'}',
            icon: Icons.paid,
          ),

          const SizedBox(height: 30),
          const Text('Контактная Информация Клиента', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
          const Divider(),

          // TODO: Получить реальные контактные данные клиента по client_id
          _buildDetailCard(
            title: 'Адрес',
            value: 'Улица Пушкина, дом Колотушкина 5 (заглушка)',
            icon: Icons.location_on,
          ),
          _buildDetailCard(
            title: 'Телефон',
            value: '+7 900 000 0000 (заглушка)',
            icon: Icons.phone,
          ),

          const SizedBox(height: 40),

          // Кнопки действий
          if (status == 'accepted')
            _buildActionButton(
              context,
              label: 'Начать Работу (в процессе)',
              icon: Icons.play_arrow,
              color: Colors.orange,
              onPressed: () => _updateOrderStatus(context, orderId, 'in_progress'),
            ),
          if (status == 'in_progress') ...[
            _buildActionButton(
              context,
              label: 'Завершить Заказ',
              icon: Icons.done_all,
              color: Colors.green,
              onPressed: () => _updateOrderStatus(context, orderId, 'completed'),
            ),
          ],
          const SizedBox(height: 15),
          _buildActionButton(
            context,
            label: 'Отменить Заказ',
            icon: Icons.cancel,
            color: Colors.redAccent,
            onPressed: () => _updateOrderStatus(context, orderId, 'cancelled'),
          ),
        ],
      ),
    );
  }

  // --- Вспомогательные виджеты ---

  Widget _buildStatusBanner(String status) {
    Color color;
    String text;
    switch (status) {
      case 'accepted':
        color = Colors.blue.shade600;
        text = 'Заказ принят. Свяжитесь с клиентом через ЧАТ!';
        break;
      case 'in_progress':
        color = Colors.orange.shade600;
        text = 'Работа в процессе. Используйте ЧАТ для координации.';
        break;
      default:
        color = Colors.grey;
        text = 'Неизвестный статус: $status';
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      width: double.infinity,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildDetailCard({required String title, required String value, required IconData icon, bool isLongText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            crossAxisAlignment: isLongText ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.indigo, size: 24),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(fontSize: isLongText ? 16 : 18, fontWeight: isLongText ? FontWeight.normal : FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, {
        required String label,
        required IconData icon,
        required Color color,
        required VoidCallback onPressed,
      }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- Логика обновления статуса ---
  Future<void> _updateOrderStatus(BuildContext context, String orderId, String newStatus) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
        if (newStatus == 'completed') 'completed_at': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Статус заказа изменен на: $newStatus')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления статуса: $e')),
        );
      }
    }
  }
}