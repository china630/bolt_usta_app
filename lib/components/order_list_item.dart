import 'package:flutter/material.dart';
import 'package:bolt_usta_app/models/order_model.dart';
import 'package:bolt_usta_app/services/user_service.dart';
import 'package:bolt_usta_app/routes.dart'; // Для доступа к функциям навигации

// Инициализация сервисов
final UserService _userService = UserService();

/// Виджет элемента списка для отображения сводки заказа.
/// Используется как на экране клиента, так и на экране мастера.
class OrderListItem extends StatelessWidget {
  final OrderModel order;
  final bool isMasterView;
  final VoidCallback onAction;
  final String actionButtonTitle;
  final Color actionButtonColor;

  const OrderListItem({
    super.key,
    required this.order,
    this.isMasterView = false,
    required this.onAction,
    required this.actionButtonTitle,
    required this.actionButtonColor,
  });

  /// Получает имя пользователя, связанного с заказом (мастер для клиента, клиент для мастера).
  Future<String> _getAssociatedUserName() async {
    final userId = isMasterView ? order.clientId : order.masterId;

    if (userId == null || userId.isEmpty) {
      return isMasterView ? 'Клиент (ID не указан)' : 'Мастер не назначен';
    }

    try {
      // Используем существующий метод сервиса для получения имени
      final userName = await _userService.getDisplayName(userId);
      return userName;
    } catch (e) {
      return 'Ошибка загрузки имени';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Определяем, какую информацию о другом пользователе нужно показать
    final String userLabel = isMasterView ? 'Клиент' : 'Мастер';
    final String associatedUserId = isMasterView ? order.clientId : order.masterId ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Заголовок и ID ---
            Text(
              order.serviceType,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'ID: ${order.orderId.substring(0, 8)}...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const Divider(height: 20),

            // --- Информация о статусе и дате ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Создан:', style: TextStyle(color: Colors.grey)),
                    Text(
                      '${order.createdAt.day}.${order.createdAt.month}.${order.createdAt.year}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Статус:', style: TextStyle(color: Colors.grey)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: order.status.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        order.status.localizedName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: order.status.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 15),

            // --- Информация о связанном пользователе (Мастер/Клиент) ---
            if (associatedUserId.isNotEmpty || isMasterView)
              FutureBuilder<String>(
                future: _getAssociatedUserName(),
                builder: (context, snapshot) {
                  String name = snapshot.data ?? 'Загрузка...';
                  // Обработка состояния загрузки/ошибки
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    name = 'Загрузка...';
                  } else if (snapshot.hasError) {
                    name = 'Ошибка: ${snapshot.error}';
                  }

                  return Row(
                    children: [
                      // Иконка в зависимости от роли
                      Icon(isMasterView ? Icons.person : Icons.handyman, size: 20, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        '$userLabel: $name',
                        style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 15),

            // --- Кнопка действия ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(isMasterView ? Icons.arrow_forward : Icons.track_changes),
                label: Text(actionButtonTitle),
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionButtonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}