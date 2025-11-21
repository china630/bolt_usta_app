import 'package:flutter/material.dart';
import '../../services/order_service.dart';
import '../../models/order_model.dart';
import '../../routes.dart';

// Инициализируем сервис
final OrderService _orderService = OrderService();

class ClientOrderWaitScreen extends StatelessWidget {
  final String orderId;

  const ClientOrderWaitScreen({super.key, required this.orderId});

  // --- Логика для завершения заказа клиентом ---
  Future<void> _completeOrder(BuildContext context) async {
    try {
      await _orderService.updateOrderStatus(
        orderId: orderId,
        newStatus: 'completed',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказ успешно завершен. Спасибо за пользование сервисом!'),
          backgroundColor: Colors.green,
        ),
      );
      // Возвращаемся на главный экран клиента
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.clientHome, (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при завершении заказа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- Виджет для отображения заказа, когда мастер принят ---
  Widget _buildInProgressUI(BuildContext context, OrderModel order) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
        const SizedBox(height: 20),
        const Text(
          'Мастер найден!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
        ),
        const SizedBox(height: 10),
        Text(
          'Мастер "${order.masterName}" принял ваш заказ по категории "${order.category}".',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 30),

        // --- Кнопка Чат ---
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pushNamed(
              Routes.chat,
              arguments: {
                'orderId': order.id,
                'otherUserName': order.masterName,
              },
            );
          },
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Связаться с Мастером (Чат)', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 15),

        // --- Кнопка Завершить ---
        OutlinedButton.icon(
          onPressed: () => _completeOrder(context),
          icon: const Icon(Icons.done_all),
          label: const Text('Заказ Выполнен (Завершить)', style: TextStyle(fontSize: 18)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.teal,
            side: const BorderSide(color: Colors.teal, width: 2),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // --- Виджет для отображения финального статуса ---
  Widget _buildFinalStatusUI(BuildContext context, OrderModel order, {required bool isCompleted}) {
    final color = isCompleted ? Colors.green.shade700 : Colors.red.shade700;
    final icon = isCompleted ? Icons.celebration : Icons.cancel;
    final title = isCompleted ? 'Заказ Успешно Завершен' : 'Заказ Отменен';
    final message = isCompleted
        ? 'Мастер "${order.masterName}" завершил работу. Спасибо!'
        : 'Заказ был отменен.';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 80, color: color),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 30),

        ElevatedButton(
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(Routes.clientHome, (route) => false),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Вернуться на Главный Экран', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отслеживание Заказа'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          // --- StreamBuilder для отслеживания заказа ---
          child: StreamBuilder<OrderModel>(
            stream: _orderService.getOrderStreamById(orderId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Text('Ошибка загрузки данных: ${snapshot.error}');
              }

              if (!snapshot.hasData) {
                return const Text('Заказ не найден.');
              }

              final order = snapshot.data!;

              switch (order.status) {
                case 'new':
                // Статус "Новый" (ожидание мастера)
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.blueAccent),
                      const SizedBox(height: 20),
                      Text(
                        'Ваш заказ (#${order.id.substring(0, 8)}) в обработке.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Идет поиск подходящего мастера. Пожалуйста, подождите.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Категория: ${order.category}\nОписание: ${order.description}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  );

                case 'in_progress':
                // Статус "В работе" (мастер принял)
                  return _buildInProgressUI(context, order);

                case 'completed':
                // Статус "Завершен"
                  return _buildFinalStatusUI(context, order, isCompleted: true);

                case 'cancelled':
                // Статус "Отменен"
                  return _buildFinalStatusUI(context, order, isCompleted: false);

                default:
                  return Text('Неизвестный статус: ${order.status}');
              }
            },
          ),
        ),
      ),
    );
  }
}